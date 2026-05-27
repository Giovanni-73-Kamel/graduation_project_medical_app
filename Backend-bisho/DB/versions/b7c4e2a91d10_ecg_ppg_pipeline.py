"""ecg ppg pipeline

Revision ID: b7c4e2a91d10
Revises: ecbbab1dbf62, a1b2c3d4e5f6
Create Date: 2026-05-20

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b7c4e2a91d10"
down_revision: Union[str, Sequence[str], None] = ("ecbbab1dbf62", "a1b2c3d4e5f6")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "devices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("label", sa.String(), nullable=True),
        sa.Column("firmware_version", sa.String(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("device_id"),
    )
    op.create_index("ix_devices_device_id", "devices", ["device_id"], unique=False)

    op.create_table(
        "sessions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("patient_id", sa.Integer(), nullable=True),
        sa.Column("sampling_rate", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), server_default="active", nullable=False),
        sa.Column("metadata_json", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["patient_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("session_id"),
    )
    op.create_index("ix_sessions_device_id", "sessions", ["device_id"], unique=False)
    op.create_index("ix_sessions_session_id", "sessions", ["session_id"], unique=False)
    op.create_index("ix_sessions_started_at", "sessions", ["started_at"], unique=False)

    op.create_table(
        "raw_readings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sampling_rate", sa.Integer(), nullable=False),
        sa.Column("ecg", sa.JSON(), nullable=False),
        sa.Column("ppg", sa.JSON(), nullable=False),
        sa.Column("battery", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(), server_default="active", nullable=False),
        sa.Column("sample_count", sa.Integer(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
        sa.Column("received_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id"], ["sessions.session_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("session_id", "timestamp", name="uq_raw_readings_session_timestamp"),
    )
    op.create_index("ix_raw_readings_device_id", "raw_readings", ["device_id"], unique=False)
    op.create_index("ix_raw_readings_session_id", "raw_readings", ["session_id"], unique=False)
    op.create_index("ix_raw_readings_timestamp", "raw_readings", ["timestamp"], unique=False)

    op.create_table(
        "analysis_results",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("model_name", sa.String(), nullable=False),
        sa.Column("model_version", sa.String(), nullable=False),
        sa.Column("status", sa.String(), server_default="completed", nullable=False),
        sa.Column("metrics", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
        sa.Column("signal_quality", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
        sa.Column("predictions", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
        sa.Column("alerts", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
        sa.Column(
            "disclaimer",
            sa.String(),
            server_default="Decision-support only, not a final medical diagnosis.",
            nullable=False,
        ),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["session_id"], ["sessions.session_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_analysis_results_session_id", "analysis_results", ["session_id"], unique=False)
    op.create_index("ix_analysis_results_created_at", "analysis_results", ["created_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_analysis_results_created_at", table_name="analysis_results")
    op.drop_index("ix_analysis_results_session_id", table_name="analysis_results")
    op.drop_table("analysis_results")

    op.drop_index("ix_raw_readings_timestamp", table_name="raw_readings")
    op.drop_index("ix_raw_readings_session_id", table_name="raw_readings")
    op.drop_index("ix_raw_readings_device_id", table_name="raw_readings")
    op.drop_table("raw_readings")

    op.drop_index("ix_sessions_started_at", table_name="sessions")
    op.drop_index("ix_sessions_session_id", table_name="sessions")
    op.drop_index("ix_sessions_device_id", table_name="sessions")
    op.drop_table("sessions")

    op.drop_index("ix_devices_device_id", table_name="devices")
    op.drop_table("devices")
