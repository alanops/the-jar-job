extends Node
class_name NPCPredictiveAI

# Predictive AI system for advanced NPC movement and decision making
# Predicts player movement and optimally positions NPCs

signal prediction_updated(predicted_position: Vector3, confidence: float)
signal interception_route_calculated(waypoints: Array[Vector3])

# Prediction parameters
@export var prediction_time_horizon: float = 5.0  # How far ahead to predict
@export var player_speed_estimate: float = 3.0    # Estimated player speed
@export var prediction_update_interval: float = 0.5  # How often to recalculate
@export var interception_enabled: bool = true

# Player tracking data
var player_position_history: Array = []  # Recent player positions
var player_velocity_samples: Array = []  # Recent velocity calculations
var current_prediction: Vector3 = Vector3.ZERO
var prediction_confidence: float = 0.0

# Prediction models
enum PredictionModel {
	LINEAR,          # Simple linear extrapolation
	CURVED,          # Account for direction changes
	BEHAVIORAL,      # Use learned patterns
	HYBRID           # Combine multiple models
}

var active_prediction_model: PredictionModel = PredictionModel.HYBRID

# Route optimization
var navigation_mesh: NavigationRegion3D
var optimal_interception_points: Array[Vector3] = []
var blocked_areas: Array[Vector3] = []  # Areas player cannot reach

# Performance tracking
var prediction_accuracy_history: Array = []
var model_performance: Dictionary = {}

func _ready():
	# Initialize model performance tracking
	for model in PredictionModel.values():
		model_performance[model] = {"accuracy": 0.5, "samples": 0}
	
	# Set up prediction update timer
	var prediction_timer = Timer.new()
	prediction_timer.wait_time = prediction_update_interval
	prediction_timer.timeout.connect(_update_predictions)
	prediction_timer.autostart = true
	add_child(prediction_timer)
	
	# Find navigation mesh
	navigation_mesh = get_tree().get_first_node_in_group("navigation")
	if not navigation_mesh:
		print("Warning: No NavigationRegion3D found for predictive AI")

func _process(delta: float):
	_collect_player_data(delta)
	_validate_predictions()

# ===================== PLAYER DATA COLLECTION =====================

func _collect_player_data(delta: float):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var current_position = player.global_position
	
	# Add to position history
	var position_data = {
		"position": current_position,
		"timestamp": current_time
	}
	player_position_history.append(position_data)
	
	# Limit history size
	if player_position_history.size() > 20:
		player_position_history = player_position_history.slice(-15)  # Keep last 15
	
	# Calculate velocity if we have enough data
	if player_position_history.size() >= 2:
		var prev_data = player_position_history[-2]
		var time_diff = current_time - prev_data.timestamp
		
		if time_diff > 0:
			var velocity = (current_position - prev_data.position) / time_diff
			var velocity_data = {
				"velocity": velocity,
				"timestamp": current_time,
				"speed": velocity.length()
			}
			player_velocity_samples.append(velocity_data)
			
			# Limit velocity samples
			if player_velocity_samples.size() > 10:
				player_velocity_samples = player_velocity_samples.slice(-8)

# ===================== PREDICTION MODELS =====================

func _update_predictions():
	if player_position_history.is_empty():
		return
	
	var predictions = {}
	var confidences = {}
	
	# Calculate predictions using different models
	predictions[PredictionModel.LINEAR] = _predict_linear()
	confidences[PredictionModel.LINEAR] = _calculate_linear_confidence()
	
	predictions[PredictionModel.CURVED] = _predict_curved()
	confidences[PredictionModel.CURVED] = _calculate_curved_confidence()
	
	predictions[PredictionModel.BEHAVIORAL] = _predict_behavioral()
	confidences[PredictionModel.BEHAVIORAL] = _calculate_behavioral_confidence()
	
	# Select best prediction based on model performance
	var best_prediction = _select_best_prediction(predictions, confidences)
	
	if best_prediction.position != current_prediction:
		current_prediction = best_prediction.position
		prediction_confidence = best_prediction.confidence
		prediction_updated.emit(current_prediction, prediction_confidence)
	
	# Calculate interception routes
	if interception_enabled:
		_calculate_interception_routes()

func _predict_linear() -> Vector3:
	if player_velocity_samples.is_empty():
		return Vector3.ZERO
	
	# Use most recent velocity for linear prediction
	var current_pos = player_position_history[-1].position
	var recent_velocity = player_velocity_samples[-1].velocity
	
	return current_pos + recent_velocity * prediction_time_horizon

func _predict_curved() -> Vector3:
	if player_velocity_samples.size() < 3:
		return _predict_linear()
	
	# Account for acceleration and direction changes
	var current_pos = player_position_history[-1].position
	var velocities = player_velocity_samples.slice(-3)  # Last 3 velocity samples
	
	# Calculate acceleration
	var v2 = velocities[-1].velocity
	var v1 = velocities[-2].velocity
	var acceleration = v2 - v1
	
	# Predict with acceleration
	var t = prediction_time_horizon
	return current_pos + v2 * t + 0.5 * acceleration * t * t

func _predict_behavioral() -> Vector3:
	# Use learned patterns from memory system
	var npc_communication = get_node("/root/NPCCommunication") as NPCCommunicationManager
	if npc_communication:
		var likely_position = npc_communication.get_most_likely_player_position()
		if likely_position != Vector3.ZERO:
			return likely_position
	
	return _predict_linear()

func _select_best_prediction(predictions: Dictionary, confidences: Dictionary) -> Dictionary:
	match active_prediction_model:
		PredictionModel.HYBRID:
			return _hybrid_prediction(predictions, confidences)
		_:
			var model = active_prediction_model
			return {"position": predictions[model], "confidence": confidences[model]}

func _hybrid_prediction(predictions: Dictionary, confidences: Dictionary) -> Dictionary:
	# Weight predictions by confidence and model performance
	var weighted_position = Vector3.ZERO
	var total_weight = 0.0
	var combined_confidence = 0.0
	
	for model in predictions.keys():
		var model_accuracy = model_performance[model]["accuracy"]
		var prediction_confidence = confidences[model]
		var weight = model_accuracy * prediction_confidence
		
		weighted_position += predictions[model] * weight
		total_weight += weight
		combined_confidence += prediction_confidence * weight
	
	if total_weight > 0:
		weighted_position /= total_weight
		combined_confidence /= total_weight
	else:
		# Fallback to linear prediction
		return {"position": predictions[PredictionModel.LINEAR], "confidence": confidences[PredictionModel.LINEAR]}
	
	return {"position": weighted_position, "confidence": combined_confidence}

# ===================== CONFIDENCE CALCULATIONS =====================

func _calculate_linear_confidence() -> float:
	if player_velocity_samples.size() < 2:
		return 0.1
	
	# Confidence based on velocity consistency
	var recent_velocities = player_velocity_samples.slice(-5)
	var velocity_variance = _calculate_velocity_variance(recent_velocities)
	
	# Lower variance = higher confidence
	return clamp(1.0 - velocity_variance / 10.0, 0.1, 1.0)

func _calculate_curved_confidence() -> float:
	if player_velocity_samples.size() < 3:
		return 0.1
	
	# Confidence based on acceleration consistency
	var base_confidence = _calculate_linear_confidence()
	
	# Boost confidence if player is following a curved path
	var recent_positions = player_position_history.slice(-5)
	var path_curvature = _calculate_path_curvature(recent_positions)
	
	return clamp(base_confidence + path_curvature * 0.3, 0.1, 1.0)

func _calculate_behavioral_confidence() -> float:
	# Confidence based on how well current behavior matches learned patterns
	var npc_communication = get_node("/root/NPCCommunication") as NPCCommunicationManager
	if npc_communication:
		var pattern_confidence = 0.0
		var shared_memory = npc_communication.shared_memory
		
		# Check if current position matches common routes
		if shared_memory.has("last_known_positions") and not shared_memory["last_known_positions"].is_empty():
			pattern_confidence = 0.7  # Base confidence for behavioral patterns
		
		return clamp(pattern_confidence, 0.1, 1.0)
	
	return 0.1

# ===================== UTILITY FUNCTIONS =====================

func _calculate_velocity_variance(velocities: Array) -> float:
	if velocities.size() < 2:
		return 0.0
	
	var mean_velocity = Vector3.ZERO
	for vel_data in velocities:
		mean_velocity += vel_data.velocity
	mean_velocity /= velocities.size()
	
	var variance = 0.0
	for vel_data in velocities:
		variance += (vel_data.velocity - mean_velocity).length_squared()
	variance /= velocities.size()
	
	return sqrt(variance)

func _calculate_path_curvature(positions: Array) -> float:
	if positions.size() < 3:
		return 0.0
	
	# Calculate how much the path curves
	var curvature = 0.0
	for i in range(1, positions.size() - 1):
		var p1 = positions[i-1].position
		var p2 = positions[i].position
		var p3 = positions[i+1].position
		
		var v1 = (p2 - p1).normalized()
		var v2 = (p3 - p2).normalized()
		
		var angle: float = v1.angle_to(v2)
		curvature += angle
	
	return curvature / (positions.size() - 2)

# ===================== INTERCEPTION SYSTEM =====================

func _calculate_interception_routes():
	if current_prediction == Vector3.ZERO or not navigation_mesh:
		return
	
	optimal_interception_points.clear()
	
	# Find points where NPCs can intercept predicted player path
	var npcs = get_tree().get_nodes_in_group("npc")
	
	for npc in npcs:
		var interception_point = _calculate_optimal_interception_point(npc, current_prediction)
		if interception_point != Vector3.ZERO:
			optimal_interception_points.append(interception_point)
	
	if not optimal_interception_points.is_empty():
		interception_route_calculated.emit(optimal_interception_points)

func _calculate_optimal_interception_point(npc: Node3D, predicted_position: Vector3) -> Vector3:
	var npc_position = npc.global_position
	var player_current = Vector3.ZERO
	
	if not player_position_history.is_empty():
		player_current = player_position_history[-1].position
	else:
		return Vector3.ZERO
	
	# Calculate where NPC should move to intercept player
	var player_to_prediction = predicted_position - player_current
	var prediction_distance = player_to_prediction.length()
	
	if prediction_distance == 0:
		return Vector3.ZERO
	
	var player_travel_time = prediction_distance / player_speed_estimate
	
	# Find point along player's predicted path where NPC can arrive in time
	var npc_speed = 2.0  # Assume NPC speed
	
	for i in range(10):  # Test 10 points along the path
		var t = float(i) / 9.0  # 0 to 1
		var test_point = player_current + player_to_prediction * t
		var npc_distance = npc_position.distance_to(test_point)
		var npc_travel_time = npc_distance / npc_speed
		var player_time_to_point = player_travel_time * t
		
		# If NPC can reach this point before or at same time as player
		if npc_travel_time <= player_time_to_point + 0.5:  # 0.5s buffer
			# Verify the point is reachable
			if _is_point_reachable(npc_position, test_point):
				return test_point
	
	return Vector3.ZERO

func _is_point_reachable(from: Vector3, to: Vector3) -> bool:
	# Simple raycast check - could be enhanced with navigation mesh queries
	# Get world from parent NPC node (which should be a CharacterBody3D)
	var parent_node = get_parent()
	if not parent_node or not parent_node.has_method("get_world_3d"):
		return true  # Assume reachable if no 3D world available
	
	var space_state = parent_node.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Only walls
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()  # Reachable if no walls in the way

# ===================== VALIDATION & LEARNING =====================

func _validate_predictions():
	# Compare past predictions with actual player positions
	if player_position_history.size() < 2:
		return
	
	var current_time = Time.get_unix_time_from_system()
	
	# Find predictions made prediction_time_horizon ago
	for accuracy_entry in prediction_accuracy_history:
		var prediction_age = current_time - accuracy_entry.timestamp
		if abs(prediction_age - prediction_time_horizon) < 0.5:  # Within 0.5 seconds
			var actual_position = player_position_history[-1].position
			var predicted_position = accuracy_entry.prediction
			var error = actual_position.distance_to(predicted_position)
			
			# Update model performance
			var model = accuracy_entry.model
			var current_accuracy = model_performance[model]["accuracy"]
			var samples = model_performance[model]["samples"]
			
			# Calculate accuracy (inverse of error, normalized)
			var new_accuracy = clamp(1.0 - error / 10.0, 0.0, 1.0)  # Max error of 10 units
			model_performance[model]["accuracy"] = (current_accuracy * samples + new_accuracy) / (samples + 1)
			model_performance[model]["samples"] = samples + 1
			
			# Remove processed entry
			prediction_accuracy_history.erase(accuracy_entry)
			break

# ===================== PUBLIC INTERFACE =====================

func get_current_prediction() -> Vector3:
	return current_prediction

func get_prediction_confidence() -> float:
	return prediction_confidence

func get_interception_points() -> Array[Vector3]:
	return optimal_interception_points.duplicate()

func set_prediction_model(model: PredictionModel):
	active_prediction_model = model

func get_model_performance() -> Dictionary:
	return model_performance.duplicate()

func debug_print_performance():
	print("=== Predictive AI Performance ===")
	for model in model_performance.keys():
		var perf = model_performance[model]
		print(PredictionModel.keys()[model], ": Accuracy=", "%.2f" % perf["accuracy"], " Samples=", perf["samples"])
	print("Current prediction: ", current_prediction, " Confidence: ", "%.2f" % prediction_confidence)
