extends Node2D
class_name WeatherSystem

# Weather system for office background
# Uses SubViewport to clip particles to sky region only

enum WeatherState { CLEAR, RAIN, SNOW }

var current_weather: WeatherState = WeatherState.CLEAR
var weather_timer: float = 0.0
var transition_time: float = 0.0

# Clipping viewport
var viewport_container: SubViewportContainer = null
var viewport: SubViewport = null

# Particle emitters (inside viewport)
var rain_particles: CPUParticles2D = null
var snow_particles: CPUParticles2D = null

# Weather timing
const MIN_WEATHER_DURATION: float = 300.0  # 5 minutes minimum
const MAX_WEATHER_DURATION: float = 900.0  # 15 minutes maximum
const TRANSITION_DURATION: float = 3.0      # Fade in/out time

# Weather probabilities (sum to 1.0)
const CLEAR_WEIGHT: float = 0.5
const RAIN_WEIGHT: float = 0.35
const SNOW_WEIGHT: float = 0.15

# Sky region height (matches back wall)
const SKY_HEIGHT: float = 76.0

func _ready() -> void:
	z_index = OfficeConstants.Z_CLOUDS
	_create_clipping_viewport()
	_create_rain_particles()
	_create_snow_particles()
	_pick_next_weather()

func _create_clipping_viewport() -> void:
	# Container clips content to its bounds
	viewport_container = SubViewportContainer.new()
	viewport_container.position = Vector2.ZERO
	viewport_container.size = Vector2(OfficeConstants.SCREEN_WIDTH, SKY_HEIGHT)
	viewport_container.stretch = true
	add_child(viewport_container)

	# Viewport renders the particles
	viewport = SubViewport.new()
	viewport.size = Vector2i(int(OfficeConstants.SCREEN_WIDTH), int(SKY_HEIGHT))
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport_container.add_child(viewport)

func _create_rain_particles() -> void:
	rain_particles = CPUParticles2D.new()
	rain_particles.emitting = false
	rain_particles.amount = 150
	rain_particles.lifetime = 0.4  # Short lifetime to stay in sky region
	rain_particles.preprocess = 0.2

	# Emission area spans full screen width, at top
	rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain_particles.emission_rect_extents = Vector2(OfficeConstants.SCREEN_WIDTH / 2, 2)
	rain_particles.position = Vector2(OfficeConstants.SCREEN_WIDTH / 2, 5)

	# Rain falls straight down, fast
	rain_particles.direction = Vector2(0.1, 1)
	rain_particles.spread = 5.0
	rain_particles.gravity = Vector2(20, 400)
	rain_particles.initial_velocity_min = 150.0
	rain_particles.initial_velocity_max = 200.0

	# Rain appearance - thin blue-gray streaks
	rain_particles.scale_amount_min = 0.5
	rain_particles.scale_amount_max = 1.0
	rain_particles.color = Color(0.6, 0.7, 0.85, 0.6)

	viewport.add_child(rain_particles)

func _create_snow_particles() -> void:
	snow_particles = CPUParticles2D.new()
	snow_particles.emitting = false
	snow_particles.amount = 60
	snow_particles.lifetime = 2.0  # Shorter lifetime for sky region
	snow_particles.preprocess = 1.0

	# Emission area spans full screen width, at top
	snow_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow_particles.emission_rect_extents = Vector2(OfficeConstants.SCREEN_WIDTH / 2, 2)
	snow_particles.position = Vector2(OfficeConstants.SCREEN_WIDTH / 2, 5)

	# Snow drifts down slowly with some horizontal wobble
	snow_particles.direction = Vector2(0, 1)
	snow_particles.spread = 30.0
	snow_particles.gravity = Vector2(0, 30)
	snow_particles.initial_velocity_min = 15.0
	snow_particles.initial_velocity_max = 30.0

	# Add some randomness to movement
	snow_particles.angular_velocity_min = -30.0
	snow_particles.angular_velocity_max = 30.0

	# Snow appearance - small white dots
	snow_particles.scale_amount_min = 1.0
	snow_particles.scale_amount_max = 2.5
	snow_particles.color = Color(0.95, 0.95, 1.0, 0.8)

	viewport.add_child(snow_particles)

func _process(delta: float) -> void:
	weather_timer -= delta

	if weather_timer <= 0:
		_pick_next_weather()
	elif weather_timer <= TRANSITION_DURATION:
		# Fading out current weather
		_update_particle_opacity(weather_timer / TRANSITION_DURATION)
	elif weather_timer >= transition_time - TRANSITION_DURATION:
		# Fading in current weather
		var fade_progress = (transition_time - weather_timer) / TRANSITION_DURATION
		_update_particle_opacity(fade_progress)

func _pick_next_weather() -> void:
	var roll = randf()
	var old_weather = current_weather

	if roll < CLEAR_WEIGHT:
		current_weather = WeatherState.CLEAR
	elif roll < CLEAR_WEIGHT + RAIN_WEIGHT:
		current_weather = WeatherState.RAIN
	else:
		current_weather = WeatherState.SNOW

	# Avoid same weather twice in a row (re-roll once)
	if current_weather == old_weather and randf() > 0.3:
		_pick_next_weather()
		return

	transition_time = randf_range(MIN_WEATHER_DURATION, MAX_WEATHER_DURATION)
	weather_timer = transition_time

	_apply_weather()

func _apply_weather() -> void:
	rain_particles.emitting = (current_weather == WeatherState.RAIN)
	snow_particles.emitting = (current_weather == WeatherState.SNOW)

	# Reset opacity for fade-in
	_update_particle_opacity(0.0)

func _update_particle_opacity(factor: float) -> void:
	factor = clampf(factor, 0.0, 1.0)

	if current_weather == WeatherState.RAIN:
		rain_particles.color.a = 0.6 * factor
	elif current_weather == WeatherState.SNOW:
		snow_particles.color.a = 0.8 * factor

func get_weather_state() -> WeatherState:
	return current_weather

func get_weather_name() -> String:
	match current_weather:
		WeatherState.CLEAR:
			return "Clear"
		WeatherState.RAIN:
			return "Rain"
		WeatherState.SNOW:
			return "Snow"
	return "Unknown"

# Force a specific weather (for testing)
func set_weather(state: WeatherState, duration: float = 60.0) -> void:
	current_weather = state
	transition_time = duration
	weather_timer = duration
	_apply_weather()
	_update_particle_opacity(1.0)
