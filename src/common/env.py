"""Environment/dotenv helpers."""

import getpass
import os

from dotenv import load_dotenv


def load_env() -> None:
    """Load variables from a .env file into the process environment."""
    load_dotenv()


def require_env(name: str, prompt: str | None = None) -> str:
    """Return an environment variable, prompting for it interactively if unset.

    The value is written back to ``os.environ`` so libraries reading it directly
    (openai, langchain, ...) pick it up.
    """
    load_env()
    value = os.environ.get(name)
    if not value:
        value = getpass.getpass(prompt or f"Enter {name}: ")
        os.environ[name] = value
    return value
