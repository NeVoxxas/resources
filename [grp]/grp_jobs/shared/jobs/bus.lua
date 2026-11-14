-- Autobuso vairuotojas: atviras darbas (be rangų), atlygis kas minutę transporte.
Config.Jobs.bus = {
    label = 'Autobuso vairuotojas',
    jobName = 'bus',        -- turi būti užregistruotas qbx_core shared jobs
    grade = 0,

    -- 'public'  = atviras, reikia tik XP
    -- 'invite'  = reikia XP ir direktoriaus / pavaduotojo pakvietimo (/priimti ID)
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

    -- Pamainos punktas: Pradėti pamainą, tada Gauti transportą / Baigti pamainą
    duty = {
        coords = vec3(453.09, -607.81, 28.59),
        distance = 2.0,
        serverDistance = 5.0
    },

    -- male: sena veikusi (testinė) uniforma.
    -- female: PAVYZDINIAI ID, dar nepatikrinti žaidime. Blogi ID nebus pritaikyti,
    -- o konsolėje matysi, kuris elementas netinka.
    -- Keli rinkiniai (pagal rangą) darbams su pakvietimu: žr. taxi.lua.example (uniforms).
    uniform = {
        male = {
            components = {
                { component_id = 3, drawable = 15, texture = 0 },
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
    },

    rewards = {
        -- Darbo XP kategorija: grp_core timeris kas minutę pamainos metu (ne AFK)
        -- prideda perMinute. Bendrą XP (Config.XP.Working) grp_core duoda pats.
        xp = { category = 'civilian', perMinute = 3 },

        -- Pinigai kas minutę, kol žaidėjas sėdi darbo transporte (ne AFK).
        -- Suma auga nuo min iki max, kai xpCategory XP pasiekia maxAtXP.
        pay = {
            account = 'bank',
            min = 100,
            max = 200,
            xpCategory = 'civilian',
            maxAtXP = 2000,
            everySeconds = 60
        }
    },

    -- Transportas gaunamas pamainos punkte (Gauti transportą)
    vehicle = {
        -- Vieta ir kryptis iš qbx_busjob (462.22, -641.15, 28.45)
        spawn = vec4(462.22, -641.15, 28.45, 175.0),
        platePrefix = 'GRP',
        models = {
            { model = 'bus', label = 'Autobusas' }
        }
    },

    -- LAIKINI maršrutai: sustojimai paimti iš qbx_busjob config. Pakeisk savais.
    -- radius: kiek metrų nuo sustojimo laikoma atvykus (numatyta 10)
    routes = {
        {
            id = 'route_1',
            label = 'Maršrutas 1',
            stops = {
                { coords = vec3(304.36, -764.56, 29.31) },
                { coords = vec3(-110.31, -1686.29, 29.31) },
                { coords = vec3(-712.83, -824.56, 23.54) },
                { coords = vec3(-692.63, -670.44, 30.86) },
                { coords = vec3(-250.14, -886.78, 30.63) }
            }
        },
        {
            id = 'route_2',
            label = 'Maršrutas 2 (atvirkščias)',
            stops = {
                { coords = vec3(-250.14, -886.78, 30.63) },
                { coords = vec3(-692.63, -670.44, 30.86) },
                { coords = vec3(-712.83, -824.56, 23.54) },
                { coords = vec3(-110.31, -1686.29, 29.31) },
                { coords = vec3(304.36, -764.56, 29.31) }
            }
        }
    }
}
