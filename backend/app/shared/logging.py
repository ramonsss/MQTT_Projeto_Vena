import sys

from loguru import logger

# Remove default handler and add structured one
logger.remove()
logger.add(
    sys.stdout,
    format="<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
    level="INFO",
    colorize=True,
)


def get_logger(name: str) -> "logger":  # type: ignore[type-arg]
    return logger.bind(context=name)
