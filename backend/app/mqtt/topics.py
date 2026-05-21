def parse_topic(topic: str) -> tuple[str, str] | None:
    """Extract (device_id, message_type) from 'vena/{device_id}/{type}'.

    Returns None if the topic doesn't match the expected pattern.
    """
    parts = topic.split("/")
    if len(parts) != 3 or parts[0] != "vena":
        return None
    return parts[1], parts[2]
