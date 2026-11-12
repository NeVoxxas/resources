-- Pavyzdinis universalios konfigūracijos darbas.
-- SVARBU: patikrink koordinates pagal savo veikiančią seno config.lua versiją.
Config.Jobs.bus = {
    label = 'Autobuso vairuotojas',
    jobName = 'bus',
    grade = 0,

    -- 'public' = įsidarbinimas per ox_target; kiti tipai automatiškai nepriimami.
    employment = {
        type = 'public',
        coords = vec3(454.2, -600.6, 28.6),
        distance = 2.0,
        serverDistance = 5.0
    },

    requirements = {
        minXP = 500,
        unemployed = true
    },

    duty = {
        coords = vec3(451.7, -603.0, 28.6),
        distance = 2.0,
        serverDistance = 5.0
    },

    -- PAVYZDINIAI drabužių ID. Suderink su sena PutOnBusUniform uniforma.
    -- Jei uniformos nenori, nurodyk uniform = nil.
    uniform = {
        male = {
            components = {
                { component_id = 3, drawable = 0, texture = 0 },
                { component_id = 4, drawable = 10, texture = 0 },
                { component_id = 6, drawable = 10, texture = 0 },
                { component_id = 8, drawable = 15, texture = 0 },
                { component_id = 11, drawable = 13, texture = 0 }
            }
        },
        female = {
            components = {
                { component_id = 3, drawable = 0, texture = 0 },
                { component_id = 4, drawable = 6, texture = 0 },
                { component_id = 6, drawable = 6, texture = 0 },
                { component_id = 8, drawable = 14, texture = 0 },
                { component_id = 11, drawable = 27, texture = 0 }
            }
        }
    }
}
