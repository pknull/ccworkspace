extends Node
class_name WeatherService

signal weather_updated(temperature: float, condition: String, location: String)

const SETTINGS_FILE: String = "user://weather_settings.json"
const REFRESH_INTERVAL: float = 900.0
const IP_GEO_URL: String = "https://ipapi.co/json/"
const GEO_URL: String = "https://geocoding-api.open-meteo.com/v1/search?name=%s&count=1&language=en&format=json"
const FORECAST_URL: String = "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=temperature_2m,weather_code&temperature_unit=%s"
const WEATHER_CLEAR: int = 0
const WEATHER_RAIN: int = 1
const WEATHER_SNOW: int = 2
const WEATHER_FOG: int = 3

var use_auto_location: bool = true
var location_query: String = ""
var use_fahrenheit: bool = false

var location_name: String = ""
var location_lat: float = NAN
var location_lon: float = NAN

var last_temperature: float = NAN
var last_condition: String = ""
var last_weather_code: int = 0
var last_temperature_unit_fahrenheit: bool = false

var saved_lat: float = NAN
var saved_lon: float = NAN
var saved_location_name: String = ""

var weather_system = null
var temperature_display = null

var ip_request: HTTPRequest
var geocode_request: HTTPRequest
var forecast_request: HTTPRequest
var refresh_timer: Timer
var request_in_flight: bool = false

func _ready() -> void:
	_register_with_settings()
	_setup_requests()
	_refresh_weather()

func _register_with_settings() -> void:
	var registry = get_node_or_null("/root/SettingsRegistry")
	if not registry:
		# Fallback to legacy loading
		_load_settings()
		return

	var schema: Array = [
		{"key": "use_auto_location", "type": "bool", "default": true, "description": "Auto-detect location via IP"},
		{"key": "location_query", "type": "string", "default": "", "description": "Custom location query (e.g. 'Seattle, WA')"},
		{"key": "use_fahrenheit", "type": "bool", "default": false, "description": "Use Fahrenheit instead of Celsius"},
		{"key": "saved_lat", "type": "float", "default": NAN, "min": -90.0, "max": 90.0, "description": "Cached latitude"},
		{"key": "saved_lon", "type": "float", "default": NAN, "min": -180.0, "max": 180.0, "description": "Cached longitude"},
		{"key": "saved_location_name", "type": "string", "default": "", "description": "Cached location name"}
	]

	registry.register_category("weather", SETTINGS_FILE, schema, _on_setting_changed)

	# Load values from registry with defaults
	var v_auto = registry.get_setting("weather", "use_auto_location")
	use_auto_location = v_auto if v_auto != null else true
	var v_query = registry.get_setting("weather", "location_query")
	location_query = v_query if v_query != null else ""
	var v_fahr = registry.get_setting("weather", "use_fahrenheit")
	use_fahrenheit = v_fahr if v_fahr != null else false
	var s_lat = registry.get_setting("weather", "saved_lat")
	var s_lon = registry.get_setting("weather", "saved_lon")
	saved_lat = NAN if s_lat == null or is_nan(float(s_lat)) else float(s_lat)
	saved_lon = NAN if s_lon == null or is_nan(float(s_lon)) else float(s_lon)
	var v_name = registry.get_setting("weather", "saved_location_name")
	saved_location_name = v_name if v_name != null else ""

func _on_setting_changed(key: String, value: Variant) -> void:
	var should_refresh = false
	match key:
		"use_auto_location":
			use_auto_location = bool(value)
			should_refresh = true
		"location_query":
			location_query = str(value) if value != null else ""
			should_refresh = true
		"use_fahrenheit":
			var new_val = bool(value)
			if use_fahrenheit != new_val:
				use_fahrenheit = new_val
				_apply_unit_conversion()
				should_refresh = true
		"saved_lat":
			saved_lat = NAN if value == null else float(value)
		"saved_lon":
			saved_lon = NAN if value == null else float(value)
		"saved_location_name":
			saved_location_name = str(value) if value != null else ""

	if should_refresh:
		_refresh_weather()

func configure(weather_node: Node, display_node: Node) -> void:
	weather_system = weather_node
	temperature_display = display_node
	_apply_cached_state()

func is_auto_location() -> bool:
	return use_auto_location

func get_location_query() -> String:
	return location_query

func is_fahrenheit() -> bool:
	return use_fahrenheit

func set_use_auto_location(enabled: bool) -> void:
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		registry.set_setting("weather", "use_auto_location", enabled)
	else:
		use_auto_location = enabled
		_save_settings()
		_refresh_weather()

func set_custom_location(query: String) -> void:
	var trimmed = query.strip_edges()
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		if trimmed == "":
			registry.set_setting("weather", "location_query", "")
			registry.set_setting("weather", "use_auto_location", true)
		else:
			registry.set_setting("weather", "location_query", trimmed)
			registry.set_setting("weather", "use_auto_location", false)
	else:
		if trimmed == "":
			location_query = ""
			use_auto_location = true
		else:
			location_query = trimmed
			use_auto_location = false
		_save_settings()
		_refresh_weather()

func set_use_fahrenheit(enabled: bool) -> void:
	if use_fahrenheit == enabled:
		return
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		registry.set_setting("weather", "use_fahrenheit", enabled)
	else:
		use_fahrenheit = enabled
		_apply_unit_conversion()
		_save_settings()
		_refresh_weather()

func _setup_requests() -> void:
	ip_request = HTTPRequest.new()
	add_child(ip_request)
	ip_request.request_completed.connect(_on_ip_request_completed)

	geocode_request = HTTPRequest.new()
	add_child(geocode_request)
	geocode_request.request_completed.connect(_on_geocode_completed)

	forecast_request = HTTPRequest.new()
	add_child(forecast_request)
	forecast_request.request_completed.connect(_on_forecast_completed)

	refresh_timer = Timer.new()
	refresh_timer.wait_time = REFRESH_INTERVAL
	refresh_timer.one_shot = false
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	add_child(refresh_timer)

func _on_refresh_timer_timeout() -> void:
	_refresh_weather()

func _refresh_weather() -> void:
	if request_in_flight:
		return
	if is_instance_valid(temperature_display):
		temperature_display.set_status("Weather...")
	if use_auto_location or location_query == "":
		_request_ip_location()
	else:
		_request_geocode(location_query)

func _request_ip_location() -> void:
	request_in_flight = true
	var err = ip_request.request(IP_GEO_URL)
	if err != OK:
		request_in_flight = false
		_handle_location_failure(true)

func _request_geocode(query: String) -> void:
	request_in_flight = true
	var encoded = _encode_query(query)
	var url = GEO_URL % encoded
	var err = geocode_request.request(url)
	if err != OK:
		request_in_flight = false
		_handle_location_failure(false)

func _request_forecast(lat: float, lon: float) -> void:
	request_in_flight = true
	var unit = "fahrenheit" if use_fahrenheit else "celsius"
	var url = FORECAST_URL % [str(lat), str(lon), unit]
	var err = forecast_request.request(url)
	if err != OK:
		request_in_flight = false
		_set_offline_state()

func _on_ip_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_handle_location_failure(true)
		return
	var data = _parse_json(body)
	if data == null or not (data is Dictionary):
		_handle_location_failure(true)
		return
	var lat = float(data.get("latitude", data.get("lat", NAN)))
	var lon = float(data.get("longitude", data.get("lon", NAN)))
	if is_nan(lat) or is_nan(lon):
		_handle_location_failure(true)
		return
	location_lat = lat
	location_lon = lon
	location_name = _format_ip_location(data)
	_save_location_cache()
	_request_forecast(lat, lon)

func _on_geocode_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_handle_location_failure(false)
		return
	var data = _parse_json(body)
	if data == null or not (data is Dictionary):
		_handle_location_failure(false)
		return
	var results = data.get("results", [])
	if results is Array and results.size() > 0:
		var entry = results[0]
		location_lat = float(entry.get("latitude", NAN))
		location_lon = float(entry.get("longitude", NAN))
		if is_nan(location_lat) or is_nan(location_lon):
			_handle_location_failure(false)
			return
		location_name = _format_geocode_location(entry)
		_save_location_cache()
		_request_forecast(location_lat, location_lon)
		return
	_handle_location_failure(false)

func _on_forecast_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_offline_state()
		return
	var data = _parse_json(body)
	if data == null or not (data is Dictionary):
		_set_offline_state()
		return
	var current = data.get("current", {})
	if not (current is Dictionary):
		_set_offline_state()
		return
	var temp_value = float(current.get("temperature_2m", NAN))
	var weather_code = int(current.get("weather_code", 0))
	if is_nan(temp_value):
		_set_offline_state()
		return
	last_temperature = temp_value
	last_weather_code = weather_code
	last_condition = _describe_weather_code(weather_code)
	last_temperature_unit_fahrenheit = use_fahrenheit
	_apply_live_weather(weather_code)
	_update_display(temp_value, last_condition)
	weather_updated.emit(temp_value, last_condition, location_name)

func _apply_cached_state() -> void:
	if is_instance_valid(temperature_display):
		if is_nan(last_temperature):
			temperature_display.set_status("Weather...")
		else:
			_apply_unit_conversion()
			_update_display(last_temperature, last_condition)
	if is_instance_valid(weather_system) and not is_nan(last_temperature):
		_apply_live_weather(last_weather_code)

func _apply_live_weather(weather_code: int) -> void:
	if not is_instance_valid(weather_system):
		return
	var state = _map_weather_code_to_state(weather_code)
	if weather_system.has_method("set_live_weather"):
		weather_system.set_live_weather(state)

func _update_display(temp_value: float, condition: String) -> void:
	if not is_instance_valid(temperature_display):
		return
	var unit_label = "F" if use_fahrenheit else "C"
	if temperature_display.has_method("set_readout"):
		temperature_display.set_readout(temp_value, unit_label, condition)

func _apply_unit_conversion() -> void:
	if is_nan(last_temperature):
		return
	if last_temperature_unit_fahrenheit == use_fahrenheit:
		return
	last_temperature = _convert_temperature(last_temperature, last_temperature_unit_fahrenheit, use_fahrenheit)
	last_temperature_unit_fahrenheit = use_fahrenheit
	_update_display(last_temperature, last_condition)

func _set_offline_state() -> void:
	if is_instance_valid(temperature_display):
		temperature_display.set_status("Weather offline")
	if is_instance_valid(weather_system) and weather_system.has_method("clear_live_weather"):
		weather_system.clear_live_weather()

func _handle_location_failure(from_auto: bool) -> void:
	if from_auto and _has_saved_location():
		location_lat = saved_lat
		location_lon = saved_lon
		location_name = saved_location_name
		_request_forecast(location_lat, location_lon)
		return
	_set_offline_state()

func _save_location_cache() -> void:
	saved_lat = location_lat
	saved_lon = location_lon
	saved_location_name = location_name
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		registry.set_setting("weather", "saved_lat", saved_lat)
		registry.set_setting("weather", "saved_lon", saved_lon)
		registry.set_setting("weather", "saved_location_name", saved_location_name)
	else:
		_save_settings()

func _has_saved_location() -> bool:
	return not is_nan(saved_lat) and not is_nan(saved_lon)

func _parse_json(body: PackedByteArray) -> Variant:
	var text = body.get_string_from_utf8()
	if text == "":
		return null
	var json = JSON.new()
	if json.parse(text) != OK:
		return null
	return json.get_data()

func _encode_query(query: String) -> String:
	var encoded = query.strip_edges()
	encoded = encoded.replace("%", "%25")
	encoded = encoded.replace(" ", "%20")
	encoded = encoded.replace(",", "%2C")
	encoded = encoded.replace("#", "%23")
	return encoded

func _format_ip_location(data: Dictionary) -> String:
	var city = str(data.get("city", ""))
	var region = str(data.get("region", ""))
	var country = str(data.get("country_name", ""))
	var parts: Array = []
	if city != "":
		parts.append(city)
	if region != "":
		parts.append(region)
	if country != "":
		parts.append(country)
	if parts.is_empty():
		return "Local"
	return ", ".join(parts)

func _format_geocode_location(entry: Dictionary) -> String:
	var name = str(entry.get("name", ""))
	var admin = str(entry.get("admin1", ""))
	var country = str(entry.get("country", ""))
	var parts: Array = []
	if name != "":
		parts.append(name)
	if admin != "":
		parts.append(admin)
	if country != "":
		parts.append(country)
	if parts.is_empty():
		return "Custom"
	return ", ".join(parts)

func _map_weather_code_to_state(code: int) -> int:
	if code in [45, 48]:
		return WEATHER_FOG
	if code in [71, 73, 75, 77, 85, 86]:
		return WEATHER_SNOW
	if code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]:
		return WEATHER_RAIN
	return WEATHER_CLEAR

func _describe_weather_code(code: int) -> String:
	match code:
		0:
			return "Clear"
		1, 2, 3:
			return "Cloudy"
		45, 48:
			return "Fog"
		51, 53, 55, 56, 57:
			return "Drizzle"
		61, 63, 65, 66, 67:
			return "Rain"
		71, 73, 75, 77:
			return "Snow"
		80, 81, 82:
			return "Showers"
		85, 86:
			return "Snow"
		95:
			return "Storm"
		96, 99:
			return "Storm"
	return "Clear"

func _convert_temperature(value: float, from_fahrenheit: bool, to_fahrenheit: bool) -> float:
	if from_fahrenheit == to_fahrenheit:
		return value
	if from_fahrenheit:
		return (value - 32.0) * (5.0 / 9.0)
	return (value * (9.0 / 5.0)) + 32.0

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		return
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if not file:
		return
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return
	var data = json.get_data()
	if data is Dictionary:
		use_auto_location = data.get("use_auto_location", true)
		location_query = data.get("location_query", "")
		use_fahrenheit = data.get("use_fahrenheit", false)
		var saved_lat_value = data.get("saved_lat", null)
		var saved_lon_value = data.get("saved_lon", null)
		saved_lat = NAN if saved_lat_value == null else float(saved_lat_value)
		saved_lon = NAN if saved_lon_value == null else float(saved_lon_value)
		saved_location_name = data.get("saved_location_name", "")

func _save_settings() -> void:
	var data = {
		"use_auto_location": use_auto_location,
		"location_query": location_query,
		"use_fahrenheit": use_fahrenheit,
		"saved_lat": null if is_nan(saved_lat) else saved_lat,
		"saved_lon": null if is_nan(saved_lon) else saved_lon,
		"saved_location_name": saved_location_name
	}
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
