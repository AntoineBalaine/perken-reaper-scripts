local mapping = {
    kind = "MainCompartment",
    version = "2.15.0",
    value = {
        groups = {
            {
                id = "S4vSFtoLZyctXfOkWqd_7",
                name = "BANK1",
                activation_condition = {
                    kind = "Bank",
                    parameter = 0,
                    bank_index = 0,
                },
            },
            {
                id = "o4DaBaqXAgKHOezxw0fFl",
                name = "BANK2",
                activation_condition = {
                    kind = "Bank",
                    parameter = 0,
                    bank_index = 1,
                },
            },
        },
        mappings = {
            {
                id = "GKr6XIMDomfdBvdUgBWq2",
                name = "V1_B1",
                group = "S4vSFtoLZyctXfOkWqd_7",
                on_activate = {
                    send_midi_feedback = {
                        {
                            kind = "Raw",
                            message =
                            "B1 00 10 B1 01 10 B1 02 10 B1 03 10 B1 04 33 B1 05 33 B1 06 33 B1 07 33 B1 08 62 B1 09 62 B1 0A 62 B1 0B 62 B1 0C 2C B1 0D 2C B1 0E 2C B1 0F 2C",
                        },
                    },
                },
                source = {
                    kind = "Virtual",
                    id = 0,
                },
                glue = {
                    step_size_interval = { 0.01, 0.05 },
                    step_factor_interval = { 1, 5 },
                },
                target = {
                    kind = "ReaperAction",
                    command = "RS86a658f69fadfd0c116968a473ed6b519f4c58cd",
                },
            },
            {
                id = "xymAWh9XDME-gCzIVUdYq",
                name = "V1_B2",
                group = "o4DaBaqXAgKHOezxw0fFl",
                on_activate = {
                    send_midi_feedback = {
                        {
                            kind = "Raw",
                            message =
                            "B1 00 03 B1 01 03 B1 02 03 B1 03 03 B1 04 65 B1 05 65 B1 06 65 B1 07 65 B1 08 45 B1 09 45 B1 0A 45 B1 0B 45 B1 0C 4F B1 0D 4F B1 0E 4F B1 0F 4F",
                        },
                    },
                },
                source = {
                    kind = "Virtual",
                    id = 0,
                },
                glue = {
                    step_size_interval = { 0.01, 0.05 },
                    step_factor_interval = { 1, 5 },
                },
                target = {
                    kind = "ReaperAction",
                    command = "RS830a2f5bc01f783a8420b014d40d85ce347e6f9b",
                },
            },
            {
                id = "05qt6I1vMb2VAB_iIcA4u",
                name = "B1_Select",
                on_activate = {
                    send_midi_feedback = {
                        {
                            kind = "Raw",
                            message =
                            "B1 00 10 B1 01 10 B1 02 10 B1 03 10 B1 04 33 B1 05 33 B1 06 33 B1 07 33 B1 08 62 B1 09 62 B1 0A 62 B1 0B 62 B1 0C 2C B1 0D 2C B1 0E 2C B1 0F 2C",
                        },
                    },
                },
                source = {
                    kind = "Virtual",
                    id = "bank-left",
                    character = "Button",
                },
                glue = {
                    target_interval = { 0, 0 },
                    out_of_range_behavior = "Min",
                    step_size_interval = { 0.01, 0.05 },
                    step_factor_interval = { 1, 5 },
                },
                target = {
                    kind = "FxParameterValue",
                    parameter = {
                        address = "ById",
                        index = 0,
                    },
                },
            },
            {
                id = "a2y2AMUJMsKwoxsijcLXM",
                name = "B2_Select",
                source = {
                    kind = "Virtual",
                    id = "bank-right",
                    character = "Button",
                },
                glue = {
                    source_interval = { 0.01, 0.01 },
                    target_interval = { 0.01, 0.01 },
                    step_size_interval = { 0.01, 0.05 },
                },
                target = {
                    kind = "FxParameterValue",
                    parameter = {
                        address = "ById",
                        index = 0,
                    },
                },
            },
        },
    },
}
return mapping
