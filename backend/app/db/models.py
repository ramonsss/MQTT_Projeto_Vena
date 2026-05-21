import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Float, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    google_sub: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    email: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    devices: Mapped[list["UserDevice"]] = relationship(back_populates="user")


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)  # "vena-a0b765c1d2e3"
    pairing_code_hash: Mapped[str] = mapped_column(Text, nullable=False)
    fw_version: Mapped[str | None] = mapped_column(Text, nullable=True)
    capabilities: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    first_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="never_connected"
    )

    users: Mapped[list["UserDevice"]] = relationship(back_populates="device")


class UserDevice(Base):
    __tablename__ = "user_devices"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    device_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("devices.id", ondelete="CASCADE"), primary_key=True
    )
    alias: Mapped[str | None] = mapped_column(Text, nullable=True)
    claimed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="devices")
    device: Mapped["Device"] = relationship(back_populates="users")


class TelemetryRaw(Base):
    __tablename__ = "telemetry_raw"

    device_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("devices.id", ondelete="CASCADE"), primary_key=True
    )
    ts: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), primary_key=True
    )
    ambient_t: Mapped[float | None] = mapped_column(Float, nullable=True)
    ambient_h: Mapped[float | None] = mapped_column(Float, nullable=True)
    diss_t: Mapped[float | None] = mapped_column(Float, nullable=True)
    diss_h: Mapped[float | None] = mapped_column(Float, nullable=True)
    setpoint: Mapped[float | None] = mapped_column(Float, nullable=True)
    pid_out: Mapped[float | None] = mapped_column(Float, nullable=True)
    uptime_ms: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    seq: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
