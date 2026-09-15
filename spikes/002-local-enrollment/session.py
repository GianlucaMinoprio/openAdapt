"""Explicit handshake core. No BLE backend, automatic enrollment, or actuators."""
import asyncio
import inspect
import math
import secrets

from crypto import Exchange, ProofFormat, encrypt, verify_peer_proof
from keyfile import validate_key


class Session:
    """One attempt only; callers own the transport and any future BLE cleanup."""

    def __init__(self, transport, *, timeout=45, exchange_factory=Exchange,
                 proof_format=ProofFormat.FULL_BLOCK):
        if not math.isfinite(timeout) or not 0 < timeout <= 120:
            raise ValueError("session timeout must be finite, > 0 and <= 120")
        if not isinstance(proof_format, ProofFormat):
            raise ValueError("unsupported peer proof format")
        self.transport = transport
        self.timeout = timeout
        self.exchange_factory = exchange_factory
        self.proof_format = proof_format
        self.state = "new"
        self.events = []

    def _begin(self, state):
        if self.state != "new":
            raise ValueError("session already used; never retry automatically")
        self.state = state

    def _abort(self):
        self.state = "failed"
        self.transport.close()

    async def _authenticate(self, key, *, completion_state="authenticated"):
        self.state = "authenticating"
        nonce = secrets.token_bytes(16)
        fields = await self.transport.request(112, nonce)
        verify_peer_proof(key, nonce, fields[1], proof_format=self.proof_format)
        await self.transport.request(113, encrypt(key, fields[2]))
        self.state = completion_state

    async def authenticate_existing(self, key):
        key = validate_key(key)  # No sentinel fallback to enrollment.
        self._begin("authenticating")
        try:
            async with asyncio.timeout(self.timeout):
                await self._authenticate(key)
        except BaseException:
            self._abort()
            raise

    async def enroll(self, store, target, *, synthetic=False):
        """Explicit new-key path; Store must be preflighted before calling.

        Persistence precedes authentication so failure does not discard a derived
        candidate. UNVERIFIED records never assert that the shoe committed a key.
        """
        if not isinstance(target, str) or not target.strip() or type(synthetic) is not bool:
            raise ValueError("invalid key metadata")
        self._begin("exchanging")
        try:
            async with asyncio.timeout(self.timeout):
                group = (await self.transport.request(110))[1]
                exchange = self.exchange_factory(group)
                peer = (await self.transport.request(111, exchange.public))[1]
                key = validate_key(exchange.derive(peer))
                store.save(key, target, synthetic=synthetic)
                self.state = "candidate-saved"
                await self._authenticate(key)
        except BaseException:
            self._abort()
            raise

    async def enroll_auto_max(self, store, target, *, synthetic=False,
                              on_key_exchange_ready=None):
        """Explicit Auto Max setup model, without any BLE lifecycle or CLI path.

        The setup key is used only here, never as an existing-key fallback. Its
        successful exchange is not possession of a private per-shoe credential.
        Candidate persistence still precedes authentication with the new key.
        """
        if self.proof_format is not ProofFormat.AUTO_MAX_2_4_3M:
            raise ValueError("explicit Auto Max proof format required")
        if not isinstance(target, str) or not target.strip() or type(synthetic) is not bool:
            raise ValueError("invalid key metadata")
        if on_key_exchange_ready is not None and (not callable(on_key_exchange_ready)
                                                  or inspect.iscoroutinefunction(on_key_exchange_ready)):
            raise ValueError("key-exchange observer must be synchronous and callable")
        self._begin("setup-authenticating")

        def ready():
            self.events.append("key-exchange-ready")
            if on_key_exchange_ready is not None:
                return on_key_exchange_ready()

        try:
            async with asyncio.timeout(self.timeout):
                await self._authenticate(b"\x01" * 16, completion_state="setup-authenticated")
                self.state = "exchanging"
                group = (await self.transport.request(110))[1]
                exchange = self.exchange_factory(group)
                peer = (await self.transport.exchange_public_key(exchange.public, on_ready=ready))[1]
                key = validate_key(exchange.derive(peer))
                store.save(key, target, synthetic=synthetic)
                self.state = "candidate-saved"
                await self._authenticate(key)
        except BaseException:
            self._abort()
            raise
