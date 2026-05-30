import uuid
from datetime import datetime

from pydantic import BaseModel


class ClaimRequest(BaseModel):
    pairing_code: str


class ClaimResponse(BaseModel):
    device_id: str
    alias: str | None
    claimed_at: datetime

    model_config = {"from_attributes": True}


class DeviceItem(BaseModel):
    device_id: str
    alias: str | None
    status: str
    last_seen_at: datetime | None
    fw_version: str | None

    model_config = {"from_attributes": True}


class DeviceListResponse(BaseModel):
    devices: list[DeviceItem]


class DeviceUpdateRequest(BaseModel):
    alias: str


class ProvisionRequest(BaseModel):
    device_id: str
    pairing_code: str


class ProvisionResponse(BaseModel):
    device_jwt: str
