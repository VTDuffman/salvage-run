class_name PlaybackClock
extends RefCounted
## Timing for run playback: how many cards fall due as time passes, at normal
## or fast speed, and how far into the current card's interval playback is
## (which drives the hit flash). Pausing freezes both.
## Plain logic with no Node or scene dependencies.

enum Speed { NORMAL, FAST }

const DEFAULT_SECONDS_PER_CARD: float = 1.5
const FAST_MULTIPLIER: float = 4.0
## Share of a card's interval the hit flash takes to fade out.
const FLASH_FRACTION: float = 0.4

## Seconds per card at normal speed.
var seconds_per_card: float = DEFAULT_SECONDS_PER_CARD
var speed: Speed = Speed.NORMAL
var paused: bool = false

## Time into the current card's interval, in normal-speed seconds.
var _elapsed: float = 0.0


## Unpauses at normal speed.
func play() -> void:
	paused = false
	speed = Speed.NORMAL


func pause() -> void:
	paused = true


## Unpauses at fast speed.
func fast_forward() -> void:
	paused = false
	speed = Speed.FAST


func speed_scale() -> float:
	return FAST_MULTIPLIER if speed == Speed.FAST else 1.0


## Advances by [param delta] real seconds and returns how many cards fell due.
## A delta spanning several intervals returns all of them.
func advance(delta: float) -> int:
	if paused or delta <= 0.0 or seconds_per_card <= 0.0:
		return 0
	_elapsed += delta * speed_scale()
	var due: int = floori(_elapsed / seconds_per_card)
	_elapsed -= due * seconds_per_card
	return due


## Progress through the current card's interval, clamped to 0..1.
func progress() -> float:
	if seconds_per_card <= 0.0:
		return 0.0
	return clampf(_elapsed / seconds_per_card, 0.0, 1.0)


## Flash strength for the card shown last: 1 when it lands, fading to 0 over
## the first FLASH_FRACTION of the interval.
func flash_strength() -> float:
	return clampf(1.0 - progress() / FLASH_FRACTION, 0.0, 1.0)
