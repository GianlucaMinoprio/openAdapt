"""All fixtures in this suite are synthetic; no radio access."""
import importlib
import importlib.util
import pytest

@pytest.fixture
def feature():
    def load(module, name):
        assert importlib.util.find_spec(module) is not None, f"Missing feature module: {module}"
        mod = importlib.import_module(module)
        assert hasattr(mod, name), f"Missing feature: {name}"
        return getattr(mod, name)
    return load
