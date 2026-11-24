class_name Schedule
extends RefCounted
## Builds an 82-game schedule in the NHL format:
##   division (7 opponents):        5 x 4 games + 2 x 3 games = 26
##   same conference, other div:    8 x 3 games               = 24
##   other conference:              16 x 2 games              = 32
## Every team gets 41 home games. Teams never play back-to-back days.


## Returns an Array of {"day": int, "home": String, "away": String}, sorted by day.
static func generate(teams: Array, rng: RandomNumberGenerator) -> Array:
	var matchups := _matchups(teams)   # Array of [home, away]
	return _assign_days(matchups, teams, rng)


static func _matchups(teams: Array) -> Array:
	var games := []
	var divisions := {}
	var conferences := {}
	for t in teams:
		if not divisions.has(t.division):
			divisions[t.division] = []
		divisions[t.division].append(t.id)
		if not conferences.has(t.conference):
			conferences[t.conference] = []
		if not conferences[t.conference].has(t.division):
			conferences[t.conference].append(t.division)
	for d in divisions:
		divisions[d].sort()

	# Division games. Neighbours on a circle play 3 times; the rest 4.
	for d in divisions:
		var ids: Array = divisions[d]
		var n := ids.size()
		for i in n:
			for j in range(i + 1, n):
				var a: String = ids[i]
				var b: String = ids[j]
				if j == i + 1 or (i == 0 and j == n - 1):
					# 3 games. On the circle, the earlier team hosts twice
					# (the wrap-around pair is reversed), so each team hosts
					# 2 + 1 across its two 3-game opponents.
					var host2 := a if j == i + 1 else b
					var host1 := b if host2 == a else a
					_add(games, host2, host1, 2)
					_add(games, host1, host2, 1)
				else:
					_add(games, a, b, 2)
					_add(games, b, a, 2)

	# Same conference, other division: 3 games, hosting alternates by index parity.
	for conf in conferences:
		var divs: Array = conferences[conf]
		for x in divs.size():
			for y in range(x + 1, divs.size()):
				var d1: Array = divisions[divs[x]]
				var d2: Array = divisions[divs[y]]
				for i in d1.size():
					for j in d2.size():
						if (i + j) % 2 == 0:
							_add(games, d1[i], d2[j], 2)
							_add(games, d2[j], d1[i], 1)
						else:
							_add(games, d1[i], d2[j], 1)
							_add(games, d2[j], d1[i], 2)

	# Other conference: home and away.
	var conf_names := conferences.keys()
	if conf_names.size() == 2:
		var east := []
		var west := []
		for t in teams:
			if t.conference == conf_names[0]:
				east.append(t.id)
			else:
				west.append(t.id)
		for a in east:
			for b in west:
				_add(games, a, b, 1)
				_add(games, b, a, 1)
	return games


static func _add(games: Array, home: String, away: String, count: int) -> void:
	for k in count:
		games.append([home, away])


static func _assign_days(matchups: Array, teams: Array, rng: RandomNumberGenerator) -> Array:
	var pool := matchups.duplicate()
	# Fisher-Yates shuffle with our own RNG so seeds are reproducible.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	var remaining := {}
	var last_day := {}
	for t in teams:
		remaining[t.id] = 0
		last_day[t.id] = -10
	for m in pool:
		remaining[m[0]] += 1
		remaining[m[1]] += 1

	var schedule := []
	var day := 0
	while not pool.is_empty():
		var playing := {}
		# Teams with the most games left get first pick of today's slots.
		var order := range(pool.size())
		order.sort_custom(func(a, b):
			return remaining[pool[a][0]] + remaining[pool[a][1]] > remaining[pool[b][0]] + remaining[pool[b][1]])
		var taken := []
		for idx in order:
			var home: String = pool[idx][0]
			var away: String = pool[idx][1]
			if playing.has(home) or playing.has(away):
				continue
			if last_day[home] >= day - 1 or last_day[away] >= day - 1:
				continue
			playing[home] = true
			playing[away] = true
			taken.append(idx)
			schedule.append({"day": day, "home": home, "away": away})
		taken.sort()
		taken.reverse()
		for idx in taken:
			var m = pool[idx]
			remaining[m[0]] -= 1
			remaining[m[1]] -= 1
			last_day[m[0]] = day
			last_day[m[1]] = day
			pool.remove_at(idx)
		day += 1
	return schedule
