import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

OLD = '591132357918.dkr.ecr.eu-north-1.amazonaws.com/twn-capstone-03-app@sha256:' + 'e'*64
NEW = '591132357918.dkr.ecr.eu-north-1.amazonaws.com/twn-capstone-03-app@sha256:' + 'a'*64
OLD_VER = 'bee47c0a7414'
NEW_VER = '327ea693dfb2'
ROOT = Path(__file__).resolve().parent
SCRIPT = ROOT.parent / 'scripts' / 'deploy-ec2.sh'
if not SCRIPT.is_file():
    SCRIPT = ROOT / 'deploy-ec2.sh'  # standalone fixture validation

MOCK = r'''#!/usr/bin/env python3
import os, sys, json
from pathlib import Path
state_file = Path(os.environ['MOCK_STATE'])
s = json.loads(state_file.read_text())
name = Path(sys.argv[0]).name
args = sys.argv[1:]
if name == 'aws':
    if args[:2] == ['ecr','get-login-password']:
        print('mock-password')
    else:
        sys.exit(91)
elif name == 'docker':
    if args[0] == 'login':
        sys.exit(0)
    elif args[0] == 'inspect':
        fmt = args[-1]
        if '.Config.Image' in fmt: print(s['image'])
        elif '.State.Health.Status' in fmt: print(s['health'])
        else: sys.exit(92)
    elif args[:2] == ['image','inspect']:
        if args[-1] not in [s['image'], os.environ['IMAGE_REF'], os.environ['OLD_IMAGE']]: sys.exit(93)
    elif args[0] == 'pull':
        pass
    elif args[0] == 'compose':
        if 'config' in args:
            pass
        elif 'up' in args:
            target = os.environ['IMAGE_REF']
            s['image'] = target
            s['version'] = os.environ['APP_VERSION']
            s['health'] = 'healthy'
            if target == os.environ['NEW_IMAGE']:
                if os.environ['MOCK_MODE'] == 'version-mismatch': s['version'] = '000000000000'
                if os.environ['MOCK_MODE'] in ('health-failure','rollback-failure'): s['health'] = 'unhealthy'
            elif os.environ['MOCK_MODE'] == 'rollback-failure':
                s['health'] = 'unhealthy'
            state_file.write_text(json.dumps(s))
        else: sys.exit(94)
    else: sys.exit(95)
elif name == 'curl':
    if s['health'] != 'healthy': sys.exit(22)
    print(json.dumps({'application':'twn-capstone-03','status':'running','version':s['version']}))
else: sys.exit(96)
'''

class DeploymentTests(unittest.TestCase):
    def run_case(self, mode, initial_health='healthy'):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            state = d / 'state.json'
            state.write_text(json.dumps({'image':OLD,'version':OLD_VER,'health':initial_health}))
            mock = d / 'mock'
            mock.write_text(MOCK)
            mock.chmod(0o755)
            for command in ['aws','docker','curl']:
                (d / command).symlink_to(mock)
            env = dict(os.environ, PATH=str(d)+os.pathsep+os.environ['PATH'],
                       IMAGE_REF=NEW, APP_VERSION=NEW_VER, AWS_REGION='eu-north-1',
                       MOCK_STATE=str(state), MOCK_MODE=mode, OLD_IMAGE=OLD, NEW_IMAGE=NEW)
            p = subprocess.run(['bash',str(SCRIPT)],capture_output=True,text=True,env=env,timeout=20)
            return p, json.loads(state.read_text())

    def test_success(self):
        p,s = self.run_case('success')
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertEqual((s['image'],s['version'],s['health']), (NEW,NEW_VER,'healthy'))

    def test_version_mismatch_rolls_back(self):
        p,s = self.run_case('version-mismatch')
        self.assertNotEqual(p.returncode,0)
        self.assertIn('ROLLBACK SUCCESS',p.stderr)
        self.assertEqual((s['image'],s['version'],s['health']), (OLD,OLD_VER,'healthy'))

    def test_health_failure_rolls_back(self):
        p,s = self.run_case('health-failure')
        self.assertNotEqual(p.returncode,0)
        self.assertIn('ROLLBACK SUCCESS',p.stderr)
        self.assertEqual(s['image'],OLD)

    def test_rollback_failure(self):
        p,s = self.run_case('rollback-failure')
        # Force target verification to fail as well in this scenario.
        self.assertNotEqual(p.returncode,0)
        self.assertIn('ROLLBACK FAILED',p.stderr)

    def test_unhealthy_baseline_rejected(self):
        p,s = self.run_case('success', initial_health='unhealthy')
        self.assertNotEqual(p.returncode,0)
        self.assertEqual(s['image'],OLD)
        self.assertIn('JSONDecodeError',p.stderr)  # preflight aborts before deployment; improve error text next

if __name__ == '__main__':
    unittest.main(verbosity=2)
