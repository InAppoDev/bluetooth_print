

import UIKit
import CoreBluetooth

protocol BluetoothPrinterDelegate: AnyObject {
	func didPrint()
	func durationPrintExpire()
}

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
	
	private var centralManager: CBCentralManager!
	private var selectedPeripheral: CBPeripheral?
	private var sendToPrinterString: String = ""
	private var userDefaults = UserDefaults.standard
	private var package: Package!
	
	weak var delegate: BluetoothPrinterDelegate?
	var isSendToPrinter = false
	
	func setup(pakage: Package) {
		centralManager = CBCentralManager(delegate: self, queue: .main)
		isSendToPrinter = false
		self.package = pakage
		sendToPrinterString = "^XA^FO40,20^APN,60,60^FDID\(package.id)^FS^FO340,20^APN,60,60^FD\(package.warehouseCellName!)^FS^FO40,75^APN,40,40^FD\(package.storeName!)^FS^FO40,118^APN,40,40^FD\(package.weight!) KG^FS^FO40,160^APN,40,40^FD\(package.recipientName)^FS^FO640,30^BQN,2,7^FDMM,AID\(package.id)^FS^XZ"
		centralManager?.scanForPeripherals(withServices: nil, options: [:])
		DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
			guard let `self` = self else { return }
			if self.isSendToPrinter == false {
				self.delegate?.durationPrintExpire()
				self.centralManager.stopScan()
			}
		}
	}
	
	
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		switch central.state {
		case .poweredOn:
			centralManager?.scanForPeripherals(withServices: nil, options: [:])
		default:
			break
		}
	}
	
	//	MARK: - CBPeripheralDelegate
	
	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		print("Discovered \(peripheral.name ?? "")")
		if (RSSI.intValue > -15) {
			return
		}
		if (RSSI.intValue < -70) {
			return
		}
		if !(peripheral.name?.isEmpty ?? true) {
			if let peripheralID = defaultPeripheralID, peripheral.identifier == UUID(uuidString: peripheralID) {
				selectedPeripheral = peripheral
				centralManager.stopScan()
				centralManager.connect(peripheral, options: [:])
			}
		}
	}
	
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		print(#function)
		peripheral.delegate = self
		peripheral.discoverServices([CBUUID(string: ZPRINTER_SERVICE_UUID), CBUUID(string: ZPRINTER_DIS_SERVICE)])
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		if let error = error {
			print(error.localizedDescription)
		} else {
			for service in peripheral.services ?? [] {
				if service.uuid == CBUUID(string: ZPRINTER_SERVICE_UUID) {
					peripheral.discoverCharacteristics([CBUUID(string: READ_FROM_ZPRINTER_CHARACTERISTIC_UUID), CBUUID(string: WRITE_TO_ZPRINTER_CHARACTERISTIC_UUID)], for: service)
					return
				}
			}
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		for characteristic in service.characteristics ?? []  {
			if characteristic.uuid == CBUUID(string: WRITE_TO_ZPRINTER_CHARACTERISTIC_UUID) {
				if let data = sendToPrinterString.data(using: .utf8) {
//					showToast(message: "Найден сервис печати и отправлено на печать")
					peripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
					isSendToPrinter = true
					delegate?.didPrint()
				}
			}
		}
		
	}
	
	func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
//		showToast(message: "розпечатано")
	}
}
