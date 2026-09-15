"""Explicit existing-key base-color/preview and lights-off operations.

Verified offline against owner-operated recordings. Live replacement LED
behavior has not been tested. No animation assets, upload or firmware API.
"""
from ble_link import ExistingKeyLink, LinkProfile
import light_wire
from transport import Transport, TransportProfile


class LightTransport(Transport):
    codec = light_wire


class AutoMaxLightLink(ExistingKeyLink):
    def __init__(self, target, **kwargs):
        if kwargs.get("profile", LinkProfile.AUTO_MAX_2_4_3M) is not LinkProfile.AUTO_MAX_2_4_3M:
            raise ValueError("lights require verified Auto Max firmware")
        kwargs["profile"] = LinkProfile.AUTO_MAX_2_4_3M
        super().__init__(target, **kwargs)
        self.operation = None
        self.result = None

    def _make_channel(self, write):
        return LightTransport(write, timeout=min(8, self.timeout), profile=TransportProfile.AUTO_MAX_CAPTURE)

    async def set_color(self, key, color):
        if self.used:
            raise ValueError("link already used; no automatic retry")
        self.operation = ("color", light_wire.rgb(color))
        await super().authenticate(key)
        return self.result

    async def lights_off(self, key):
        if self.used:
            raise ValueError("link already used; no automatic retry")
        self.operation = ("off", (0, 0, 0))
        await super().authenticate(key)
        return self.result

    async def _after_authentication(self):
        if self.operation is None:
            return
        action, color = self.operation
        # Stop any running effect before a new base color or Lights Off.
        await self.channel.request(237)
        self.events.append("animation-stopped")
        await self.channel.request(222, color)
        self.events.append("base-color-acknowledged")
        if action == "color":
            await self.channel.request(20)
            self.events.append("color-preview-acknowledged")
        self.result = {"action": action, "rgb": list(color), "acknowledged": True}
