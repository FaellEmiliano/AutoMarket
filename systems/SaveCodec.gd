extends RefCounted
## Portable authenticated save envelope. Keys in a local client deter casual editing,
## but cannot establish trusted progress against a modified client.

const FORMAT := "automarket-save"
const ENVELOPE_VERSION := 1
const MAX_BYTES := 1024 * 1024
const BLOCK_BYTES := 16
const ENCRYPTION_KEY := "48b4bec97d86ba406423079c6ffec17f7e192d8595079198c99b199f9d2a302b"
const AUTHENTICATION_KEY := "ca9d2f2f28f38f93d2c64683b22c7563a08c0bf1317902b6bc1da555aebe3efe"

static func encode(data: Dictionary) -> String:
	var plain := JSON.stringify(data).to_utf8_buffer()
	var padding := BLOCK_BYTES - plain.size() % BLOCK_BYTES
	for index in range(padding):
		plain.append(padding)
	var crypto := Crypto.new()
	var iv := crypto.generate_random_bytes(BLOCK_BYTES)
	if iv.size() != BLOCK_BYTES:
		return ""
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT, ENCRYPTION_KEY.hex_decode(), iv) != OK:
		return ""
	var encrypted := aes.update(plain)
	aes.finish()
	if encrypted.size() != plain.size():
		return ""
	var digest := _authenticate(iv, encrypted)
	if digest.size() != 32:
		return ""
	var text := JSON.stringify({
		"format": FORMAT,
		"version": ENVELOPE_VERSION,
		"iv": Marshalls.raw_to_base64(iv),
		"payload": Marshalls.raw_to_base64(encrypted),
		"hmac": digest.hex_encode()
	})
	return text if text.to_utf8_buffer().size() <= MAX_BYTES else ""

static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	var envelope: Dictionary = json.data
	if envelope.size() != 5 or envelope.get("format") != FORMAT or envelope.get("version") != ENVELOPE_VERSION:
		return {}
	for field in ["iv", "payload", "hmac"]:
		if not (envelope.get(field) is String):
			return {}
	var iv := _decode_base64(envelope["iv"])
	var encrypted := _decode_base64(envelope["payload"])
	var tag: String = envelope["hmac"]
	if tag.length() != 64:
		return {}
	for index in range(tag.length()):
		if not tag.substr(index, 1) in "0123456789abcdef":
			return {}
	var received := tag.hex_decode()
	if iv.size() != BLOCK_BYTES or encrypted.is_empty() or encrypted.size() % BLOCK_BYTES != 0:
		return {}
	if received.size() != 32 or received.hex_encode() != envelope["hmac"]:
		return {}
	var expected := _authenticate(iv, encrypted)
	if expected.size() != 32 or not Crypto.new().constant_time_compare(expected, received):
		return {}
	# Authenticate header, IV and ciphertext before attempting decryption.
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, ENCRYPTION_KEY.hex_decode(), iv) != OK:
		return {}
	var plain := aes.update(encrypted)
	aes.finish()
	if plain.is_empty():
		return {}
	var padding := int(plain[plain.size() - 1])
	if padding < 1 or padding > BLOCK_BYTES or padding > plain.size():
		return {}
	for index in range(plain.size() - padding, plain.size()):
		if plain[index] != padding:
			return {}
	plain.resize(plain.size() - padding)
	if json.parse(plain.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return {}
	return json.data

static func _authenticate(iv: PackedByteArray, encrypted: PackedByteArray) -> PackedByteArray:
	var message := (FORMAT + ":" + str(ENVELOPE_VERSION) + ":").to_utf8_buffer()
	message.append_array(iv)
	message.append_array(encrypted)
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, AUTHENTICATION_KEY.hex_decode(), message)

static func _decode_base64(text: String) -> PackedByteArray:
	if text.is_empty() or text.length() % 4 != 0:
		return PackedByteArray()
	for index in range(text.length()):
		var character := text.substr(index, 1)
		if character == "=" and index >= text.length() - 2:
			continue
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/":
			return PackedByteArray()
	var bytes := Marshalls.base64_to_raw(text)
	return bytes if Marshalls.raw_to_base64(bytes) == text else PackedByteArray()
