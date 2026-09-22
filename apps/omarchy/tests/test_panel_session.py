import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parents[1]/'backend'))
import openadapt_session as session


def pair(ident='first'):
    return {'id':ident, 'name':'Test '+ident, 'shoes':{
        side:{'profile':'auto-max-2.4.3M', 'credential_status':'hardware-verified',
              'address':'02:00:00:00:00:'+('01' if side=='left' else '02'),
              'advertised_name':'004-TEST-000', 'key_hex':bytes(range(16)).hex(), 'fit_maximum':60}
        for side in session.storage.SIDES}}


class FakeLink:
    instances=[]
    fail_right=False
    def __init__(self, target, *, on_change, trace):
        self.side='left' if target.address.endswith('01') else 'right'
        self.changed=on_change
        self.connected=False
        self.calls=[]
        self.instances.append(self)
    async def start(self,key):
        self.calls.append('connect')
        if self.fail_right and self.side=='right':
            raise ConnectionError('private identity should not be displayed')
        self.connected=True
        return {'raw_position':30,'battery_percent':88,'charger_status':1,'battery_state':4}
    async def stop(self):
        self.calls.append('disconnect'); self.connected=False
        self.changed('disconnected',None)
    async def execute(self,action,**kwargs):
        self.calls.append(action)
        if action=='battery':
            return {'before':{'raw_position':30,'battery_percent':88}}
        if action=='lace':
            return {'before':{'raw_position':30,'battery_percent':88},'after_raw_position':45}
        return {}


@pytest.fixture
def controller(tmp_path,monkeypatch):
    monkeypatch.setattr(session.storage,'STATE',tmp_path/'state')
    monkeypatch.setattr(session.storage,'CONFIG',tmp_path/'config')
    FakeLink.instances=[]; FakeLink.fail_right=False
    return session.Controller(entries=[pair(),pair('second')],link_factory=FakeLink)


def test_startup_lists_saved_pairs_with_no_radio_or_fake_connection(controller):
    result=controller.public()
    assert [p['id'] for p in result['saved_pairs']]==['first','second']
    assert not result['connected'] and FakeLink.instances==[]
    assert not any(f['connected'] for f in result['feet'].values())
    text=str(result)
    assert 'key_hex' not in text and 'address' not in text and 'TEST-000' not in text


async def test_choose_connect_then_reuse_both_links_for_controls(controller):
    await controller.dispatch({'action':'connect','pair_id':'first'})
    assert controller.public()['connected']
    assert all(f['connected'] for f in controller.public()['feet'].values())
    await controller.dispatch({'action':'battery'})
    await controller.dispatch({'action':'lace','side':'left','percent':75})
    assert len(FakeLink.instances)==2
    assert FakeLink.instances[0].calls==['connect','battery','lace']
    assert FakeLink.instances[1].calls==['connect','battery']
    assert controller.public()['feet']['left']['percent']==75
    await controller.dispatch({'action':'disconnect'})
    assert not controller.public()['connected']


async def test_selecting_another_pair_disconnects_old_links(controller):
    await controller.dispatch({'action':'connect','pair_id':'first'})
    previous=list(FakeLink.instances)
    await controller.dispatch({'action':'connect','pair_id':'second'})
    assert all(not link.connected and link.calls[-1]=='disconnect' for link in previous)
    assert controller.public()['selected_id']=='second'
    await controller.disconnect()


async def test_relaunch_does_not_restore_cached_connection(controller):
    await controller.dispatch({'action':'connect','pair_id':'first'})
    await controller.disconnect()
    relaunched=session.Controller(entries=[pair()],link_factory=FakeLink)
    assert not relaunched.public()['connected'] and len(FakeLink.instances)==2


async def test_partial_connection_keeps_working_shoe_and_scopes_battery(controller):
    FakeLink.fail_right=True
    await controller.dispatch({'action':'connect','pair_id':'first'})
    result=controller.public()
    assert result['connected'] and result['feet']['left']['connected']
    assert not result['feet']['right']['connected'] and result['failed']
    assert 'private identity' not in result['message']
    await controller.dispatch({'action':'battery'})
    assert FakeLink.instances[0].calls==['connect','battery']
    assert FakeLink.instances[1].calls==['connect','disconnect']
    with pytest.raises(session.storage.UserError):
        await controller.dispatch({'action':'color','side':'both','color':'green'})
    await controller.disconnect()


async def test_disconnected_action_cannot_queue_for_later(controller):
    with pytest.raises(session.storage.UserError):
        await controller.dispatch({'action':'lace','side':'left','percent':75})
    assert FakeLink.instances==[]
    await controller.dispatch({'action':'connect','pair_id':'first'})
    assert all(link.calls==['connect'] for link in FakeLink.instances)
    await controller.disconnect()


async def test_unsupported_profile_never_constructs_connection(controller):
    controller.entries[0]['shoes']['left']['profile']='unverified'
    assert not controller.public()['saved_pairs'][0]['connectable']
    with pytest.raises(session.storage.UserError):
        await controller.dispatch({'action':'connect','pair_id':'first'})
    assert FakeLink.instances==[]


def test_empty_catalog_is_a_real_empty_list(controller):
    controller.entries=[]
    assert controller.public()['saved_pairs']==[] and not controller.public()['connected']


@pytest.mark.parametrize('command',[{'action':'preview'},{'action':'reset'},{'action':'pair'},
    {'action':'connect','pair_id':'../path'},{'action':'lace','side':'left','percent':7}])
def test_unsupported_requests_cannot_reach_hardware(command):
    with pytest.raises(session.storage.UserError):
        session.validate_request(command)


def test_old_profile_catalog_is_read_without_rewriting_credentials(controller):
    source=session.storage.CONFIG/'profiles.private.json'
    session.storage.write_json(source,{'version':1,'shoes':pair()['shoes']})
    before=source.read_bytes(); result=session.catalog()
    assert len(result)==1 and result[0]['id']=='auto-max' and source.read_bytes()==before


def test_multiple_saved_pairs_keep_their_order(controller):
    source=session.storage.CONFIG/'profiles.private.json'
    session.storage.write_json(source,{'version':2,'pairs':[pair('second'),pair('first')]})
    assert [p['id'] for p in session.catalog()]==['second','first']
