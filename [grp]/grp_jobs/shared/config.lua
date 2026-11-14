Config = Config or {}
Config.Debug = false
Config.Jobs = {}

Config.JoinCooldownMs = 2000
Config.DutyCooldownMs = 2000
Config.UniformTimeoutMs = 10000
Config.ManageCooldownMs = 1000
Config.VehicleCooldownMs = 3000

-- Darbai su pakvietimu
Config.InviteHours = 24                  -- kiek valandų galioja pakvietimas
Config.Ranks = { min = 5, max = 15 }     -- direktorius gali keisti rangų skaičių šiose ribose

-- Atlygis: grp_jobs tikrina kas PayTickSeconds, o mokama kai žaidėjas
-- pakankamai laiko (pay.everySeconds) praleido darbo transporte ir nebuvo AFK.
Config.PayTickSeconds = 10

-- Darbų aprašai: shared/jobs/<darbas>.lua
-- Naujas darbas = naujas failas. Pavyzdys darbui su pakvietimu: shared/jobs/taxi.lua.example
