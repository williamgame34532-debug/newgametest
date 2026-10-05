local FACTION = {}
FACTION.name = "factionWorker"
FACTION.description = "factionWorkerDescription"
FACTION.icon = "framework/icons/worker.png"
FACTION.color = Color(226, 190, 84)
FACTION.bWhitelist = true
FACTION.bCWU = true
FACTION.models = table.Copy(NETWORK.factions.Get("citizen").models)
NETWORK.factions.Register("worker", FACTION)
