from PySide6.QtWidgets import QWidget, QLabel, QVBoxLayout, QPushButton
from PySide6.QtCore import Qt, Signal


class ConnectedPage(QWidget):
    disconnect_requested = Signal()

    def __init__(self):
        super().__init__()

        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(12)

        title = QLabel("RemoteHub Agent")
        title.setObjectName("title")
        title.setAlignment(Qt.AlignCenter)

        self.status = QLabel("● Connected")
        self.status.setObjectName("status")

        self.device_label = QLabel("Device: -")
        self.online_label = QLabel("Status: -")

        running_label = QLabel("Running in background")

        layout.addWidget(title)
        layout.addWidget(self.status)
        layout.addWidget(self.device_label)
        layout.addWidget(self.online_label)
        layout.addWidget(running_label)

        disconnect_btn = QPushButton("Disconnect")
        disconnect_btn.setObjectName("disconnect")
        disconnect_btn.clicked.connect(self.disconnect_requested.emit)

        layout.addWidget(disconnect_btn)
        layout.addStretch()

    def set_device(self, name: str):
        self.device_label.setText(f"Device: {name}")

    def set_status(self, status: str):
        self.online_label.setText(f"Status: {status}")