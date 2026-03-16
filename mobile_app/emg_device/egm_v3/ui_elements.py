from PyQt5 import QtWidgets, QtCore
from PyQt5.QtGui import QFont
from PyQt5.QtWidgets import QApplication, QStyle
from matplotlib import pyplot as plt
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from plot_maker import plot_data
from consts import ConstValues

def setup_buttons(self):
    self.button_layout = QtWidgets.QHBoxLayout()
    
    self.scan_button = QtWidgets.QPushButton("Scan Device")
    self.scan_button.setFixedSize(150, 30)
    
    self.status_label = QtWidgets.QLabel("No Bluetooth device connected")
    self.status_label.setFont(QFont("Arial", weight=QFont.Bold))
    
    self.slider = QtWidgets.QSlider(QtCore.Qt.Horizontal)
    self.slider.setRange(100, 10000)
    self.slider.setValue(5000)
    self.slider.setTickPosition(QtWidgets.QSlider.TicksBelow)
    self.slider.setTickInterval(1000)
    self.slider.valueChanged.connect(self.update_plot_range_value)
    self.slider.setFixedSize(200, 30)

    
    self.d_info_button = QtWidgets.QPushButton("Device Info")
    self.d_info_button.setFixedSize(100, 30)
    self.d_info_button.setEnabled(False)
    
    self.start_button = QtWidgets.QPushButton("Start Test")
    self.start_button.setFixedSize(100, 30)
    self.start_button.setEnabled(False)
    
    self.stop_button = QtWidgets.QPushButton("Stop Test")
    self.stop_button.setFixedSize(100, 30)
    self.stop_button.setEnabled(False)
    
    self.save_data_toggle = QtWidgets.QCheckBox("Save file as CSV")
    self.save_data_toggle.setChecked(False)
    
    self.reset_button = QtWidgets.QPushButton()
    self.reset_button.setFixedSize(30, 30)
    reset_icon = QApplication.style().standardIcon(QStyle.SP_BrowserReload)
    self.reset_button.setIcon(reset_icon)
    
    self.dropdown_button = QtWidgets.QPushButton()
    self.dropdown_button.setFixedSize(30, 30)
    menu_icon = QApplication.style().standardIcon(QStyle.SP_FileDialogListView)
    self.dropdown_button.setIcon(menu_icon)
    
    self.bandpass_filter_toggle = QtWidgets.QCheckBox("Filter: "+ConstValues.FILTER_LIST[0])
    self.bandpass_filter_toggle.setChecked(True)
    self.low_pass_toggle = QtWidgets.QCheckBox("Filter: "+ConstValues.FILTER_LIST[1])
    self.low_pass_toggle.setChecked(False)
    self.high_pass_toggle = QtWidgets.QCheckBox("Filter: "+ConstValues.FILTER_LIST[2])
    self.high_pass_toggle.setChecked(False)
    self.notch_filter_toggle = QtWidgets.QCheckBox("Filter: "+ConstValues.FILTER_LIST[3])
    self.notch_filter_toggle.setChecked(False)
    self.compeare_filter_toggle = QtWidgets.QCheckBox("Compare raw and filtered")
    self.compeare_filter_toggle.setChecked(False)
    
    self.dropdown_menu = QtWidgets.QMenu()
    self.save_data_actions = QtWidgets.QWidgetAction(self.dropdown_menu)
    self.save_data_actions.setDefaultWidget(self.save_data_toggle)
    
    self.bandpass_filter_actions = QtWidgets.QWidgetAction(self.dropdown_menu)
    self.bandpass_filter_actions.setDefaultWidget(self.bandpass_filter_toggle)
    self.low_pass_toggle_action = QtWidgets.QWidgetAction(self.dropdown_menu)
    self.low_pass_toggle_action.setDefaultWidget(self.low_pass_toggle)
    self.high_pass_toggle_action = QtWidgets.QWidgetAction(self.dropdown_menu)
    self.high_pass_toggle_action.setDefaultWidget(self.high_pass_toggle)
    self.notch_filter_toggle_action = QtWidgets.QWidgetAction(self.dropdown_menu)
    self.notch_filter_toggle_action.setDefaultWidget(self.notch_filter_toggle)
    self.compeare_filter_toggle_action = QtWidgets.QWidgetAction(self.dropdown_menu)
    self.compeare_filter_toggle_action.setDefaultWidget(self.compeare_filter_toggle)
    
    self.dropdown_menu.addAction(self.save_data_actions)
    self.dropdown_menu.addAction(self.bandpass_filter_actions)
    self.dropdown_menu.addAction(self.low_pass_toggle_action)
    self.dropdown_menu.addAction(self.high_pass_toggle_action)
    self.dropdown_menu.addAction(self.notch_filter_toggle_action)
    self.dropdown_menu.addAction(self.compeare_filter_toggle_action)
    
    self.dropdown_button.setMenu(self.dropdown_menu)
    
    self.button_layout.addWidget(self.scan_button)
    self.button_layout.addWidget(self.status_label)
    self.button_layout.addWidget(self.slider)
    self.button_layout.addWidget(self.reset_button)
    self.button_layout.addWidget(self.d_info_button)
    self.button_layout.addWidget(self.start_button)
    self.button_layout.addWidget(self.stop_button)
    self.button_layout.addWidget(self.dropdown_button)
    
    self.layout.addLayout(self.button_layout)
    
def setup_canvas(self):
    self.figure = plt.figure()
    self.canvas = FigureCanvas(self.figure)
    self.layout.addWidget(self.canvas)
    
def setup_connections(self):
    self.scan_button.clicked.connect(self.ble_connection_toggle)
    self.reset_button.clicked.connect(lambda:plot_data(self,reset=True))
    self.d_info_button.clicked.connect(self.send_command)
    self.start_button.clicked.connect(self.subscribe_to_notifications_2)
    self.stop_button.clicked.connect(self.unsubscribe_from_notification_2)