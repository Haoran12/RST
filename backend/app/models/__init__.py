from nanoid import generate

ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
ID_LENGTH = 12


def generate_id() -> str:
    """Generate a 12-char nanoid using 0-9a-z alphabet."""
    return generate(ALPHABET, ID_LENGTH)


__all__ = ["generate_id", "ALPHABET", "ID_LENGTH"]
