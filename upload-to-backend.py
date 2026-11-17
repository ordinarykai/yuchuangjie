"""Upload a completed DMG through the authorized production file API."""
from pathlib import Path
import argparse
import http.client
import json
import os
import urllib.request
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--architecture', required=True, choices=['arm64', 'x86_64'])
parser.add_argument('--version', required=True)
args = parser.parse_args()
source_dir = Path('output') / args.architecture
files = list(source_dir.glob('*.dmg'))
assert len(files) == 1, 'Expected exactly one DMG'
source = files[0]
assert f'-{args.version}-macos-{args.architecture}.dmg' in source.name
token = os.environ.pop('ATAI_MACOS_UPLOAD_TOKEN')
assert token, 'Upload credential is unavailable'
boundary = 'AtaiMacos' + uuid.uuid4().hex
prefix = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{source.name}"\r\nContent-Type: application/octet-stream\r\n\r\n').encode()
suffix = f'\r\n--{boundary}--\r\n'.encode()
connection = http.client.HTTPSConnection('cqsaigc.com', timeout=600)
try:
    connection.putrequest('POST', '/backend/atai-video-business-file/api/file-manage/upload/res')
    for key, value in {'Token': token, 'Content-Type': 'multipart/form-data; boundary=' + boundary,
                       'Content-Length': str(len(prefix) + source.stat().st_size + len(suffix)),
                       'Origin': 'https://cqsaigc.com', 'Accept': 'application/json'}.items():
        connection.putheader(key, value)
    connection.endheaders()
    connection.send(prefix)
    sent = 0
    with source.open('rb') as stream:
        while chunk := stream.read(1024 * 1024):
            connection.send(chunk)
            sent += len(chunk)
            if sent % (64 * 1024 * 1024) == 0 or sent == source.stat().st_size:
                print('Uploaded', args.architecture, sent, '/', source.stat().st_size, flush=True)
    connection.send(suffix)
    response = connection.getresponse()
    result = json.loads(response.read())
    assert response.status == 200 and result.get('code') == '00000000', 'File upload was rejected'
finally:
    connection.close()
file_id = result['data']
if isinstance(file_id, list):
    file_id = file_id[0]['fileId']
elif isinstance(file_id, dict):
    file_id = file_id['fileId']
assert isinstance(file_id, str) and file_id


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *unused):
        raise RuntimeError('Authenticated API request redirected')


request = urllib.request.Request(
    'https://cqsaigc.com/backend/atai-video-business-system/admin-api/local-assistant/release/artifact/register',
    data=json.dumps({'appVersion': args.version, 'platform': 'macos', 'fileId': file_id}).encode(),
    headers={'Token': token, 'Content-Type': 'application/json', 'Accept': 'application/json', 'Accept-Language': 'zh-CN'},
    method='POST')
with urllib.request.build_opener(NoRedirect).open(request, timeout=600) as response:
    registered = json.load(response)
assert registered.get('code') == '00000000', 'Artifact registration was rejected'
artifact = registered['data']
expected_sha = source.with_name(source.name + '.sha256').read_text('utf-8').split()[0]
assert artifact['sha256'] == expected_sha and artifact['size'] == source.stat().st_size
record = {
    'appVersion': args.version, 'architecture': 'arm64' if args.architecture == 'arm64' else 'x64',
    'fileId': file_id, 'sourceName': source.name, 'size': source.stat().st_size,
    'registered': registered, 'signatureVerified': False, 'notarized': False, 'autoUpdateEnabled': False}
out = Path('registration')
out.mkdir(exist_ok=True)
(out / (args.architecture + '.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
print('Registered macOS', args.version, args.architecture, source.stat().st_size, 'bytes; manual installation only', flush=True)
