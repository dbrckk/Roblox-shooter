local WeaponConfig = {}

WeaponConfig.Order = {
	"Pistol",
	"Sniper",
	"Knife",
}

WeaponConfig.Definitions = {
	Pistol = {
		displayName = "Pistol",
		kind = "Raycast",
		fireCooldown = 0.22,
		damage = 36,
		headshotDamage = 100,
		range = 700,
		fireSoundId = "rbxasset://sounds/electronicpingshort.wav",
		fireVolume = 0.55,
		firePlaybackSpeed = 0.68,
		soundLayers = {
			{ soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.62, playbackSpeed = 0.58 },
			{ soundId = "rbxasset://sounds/snap.wav", volume = 0.18, playbackSpeed = 1.35 },
		},
		recoilKick = 0.1,
	},

	Sniper = {
		displayName = "Sniper",
		kind = "Raycast",
		fireCooldown = 1.15,
		damage = 82,
		headshotDamage = 150,
		range = 1500,
		zoomFieldOfView = 32,
		fireSoundId = "rbxasset://sounds/bass.wav",
		fireVolume = 0.75,
		firePlaybackSpeed = 1.15,
		soundLayers = {
			{ soundId = "rbxasset://sounds/bass.wav", volume = 0.82, playbackSpeed = 1.08 },
			{ soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.28, playbackSpeed = 0.42 },
		},
		recoilKick = 0.18,
	},

	Knife = {
		displayName = "Throwing Knife",
		kind = "Projectile",
		fireCooldown = 0.78,
		damage = 100,
		headshotDamage = 100,
		range = 290,
		projectileSpeed = 190,
		projectileLifetime = 2.1,
		fireSoundId = "rbxasset://sounds/snap.wav",
		fireVolume = 0.5,
		firePlaybackSpeed = 1.2,
		soundLayers = {
			{ soundId = "rbxasset://sounds/snap.wav", volume = 0.5, playbackSpeed = 1.15 },
			{ soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.12, playbackSpeed = 1.8 },
		},
		recoilKick = 0.08,
	},
}

function WeaponConfig.get(weaponId)
	return WeaponConfig.Definitions[weaponId]
end

function WeaponConfig.isValid(weaponId)
	return WeaponConfig.Definitions[weaponId] ~= nil
end

return WeaponConfig
