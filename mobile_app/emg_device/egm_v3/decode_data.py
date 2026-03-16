def parse_device_info(self,raw_bytes: bytes):
    val = bytearray(raw_bytes)

    # According to the provided documentation, 
    # Find the delimiter: [0x0A, 0x00, 0x00]
    delimiter_index = -1
    for i in range(len(val) - 2):
        if val[i] == 0x0A and val[i+1] == 0x00 and val[i+2] == 0x00:
            delimiter_index = i
            break

    if delimiter_index == -1:
        raise ValueError("Delimiter not found in device info data")

    # UUID is from start to 6 bytes before delimiter
    uuid_bytes = val[0:delimiter_index - 6]
    uuid_str = ''.join(f'{b:02X}' for b in uuid_bytes)

    # Device version: S or P
    version_byte = val[delimiter_index - 6]
    self.version = 'S' if version_byte == ord('S') else 'P'

    # Direction: ASCII '0' is 48; subtract 48
    direction_byte = val[delimiter_index - 5]
    self.direction = 'Left' if direction_byte == 48 else 'Right'

    # Threshold: 4 ASCII bytes before delimiter
    threshold_bytes = val[delimiter_index - 4:delimiter_index]
    threshold_str = ''.join(str(b - 48) for b in threshold_bytes)
    self.threshold = int(threshold_str)
    self.start_button.setEnabled(True)
    return None


def parse_show_data(self,raw_bytes: bytes, threshold: int) -> list:
    # Convert to byte array and skip the first 5 byte
    data = raw_bytes[5:]
    
    results = []
    for i in range(0, len(data), 2):
        if i + 1 < len(data):
            # Combine two bytes into a 16-bit integer (little endian)
            value = data[i] + (data[i + 1] << 8)
            # Subtract threshold
            adjusted_value = value - threshold
            results.append(adjusted_value)
    return results