
Config.Jobs = Config.Jobs or {}

Config.Jobs.bus = {
    label = 'Autobuso vairuotojas',
    jobName = 'bus',
    type = 'civilian',

    requiredXP = 500,
    grade = 0,

    xpCategory = 'civilian',

    rewards = {
        salary = 50,
        jobXP = 2
    },

    locations = {
        employment = vec3(454.2, -600.6, 28.6),
        duty = vec3(451.7, -603.0, 28.6)
    },

    uniform = {
        enabled = true,
        male = {},
        female = {}
    },

    vehicles = {
        enabled = true,
        models = { 'bus' }
    }
}
