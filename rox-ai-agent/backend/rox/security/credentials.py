"""API keys go to the OS credential vault (Windows Credential Manager via keyring). Never to disk/DB/logs."""
import keyring
from keyring.errors import KeyringError, PasswordDeleteError

SERVICE = "ROX-AI-Agent"


def set_secret(name: str, value: str) -> None:
    keyring.set_password(SERVICE, name, value)


def get_secret(name: str) -> str | None:
    try:
        return keyring.get_password(SERVICE, name)
    except KeyringError:
        return None


def delete_secret(name: str) -> None:
    try:
        keyring.delete_password(SERVICE, name)
    except (PasswordDeleteError, KeyringError):
        pass


def mask(value: str | None) -> str | None:
    if not value:
        return None
    return value[:7] + "…" + value[-4:] if len(value) > 12 else "••••"
