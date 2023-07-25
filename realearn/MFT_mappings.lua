local Bank_selectors = {
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
}

local B1_mappings = {
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
        id = "3tICfLtgYaMUrEtRF-j0-",
        name = "V2_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 1,
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
        id = "VEGCtvC7As8JvuwAT7MDL",
        name = "V3_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 2,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS7ad216177f674727876f6db23cd4ec198c041924",
        },
    },
    {
        id = "f6s6xksXI1P5ORtfttJUQ",
        name = "V4_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 3,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RScad496a247fdbb534da3a99df0b31f12c6195699",
        },
    },
    {
        id = "O1TA84rxsfsXcWa9mt2gZ",
        name = "V5_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 4,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS32313842f86d8a75dd381cd4a388d9c9101142d9",
        },
    },
    {
        id = "3oGY61kvfdZkxdErl6YKW",
        name = "V6_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 5,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS616a6d79328be95d99b095362456360bce9573dc",
        },
    },
    {
        id = "T3ykjm7UmcEmWYhmrjl7i",
        name = "V7_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 6,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSb9c4a112e8da743767779d4ef215fda6e77f7944",
        },
    },
    {
        id = "T0PYrvAkeHortwH7pppcf",
        name = "V8_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 7,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS5e00b697a621faca3c972d40b8490d284d28eba2",
        },
    },
    {
        id = "1NXUfzIkeBH4g6bKDwPIC",
        name = "V9_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 8,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSdc0e41cf2f89ed30e2937a6966919cd3b39c5525",
        },
    },
    {
        id = "T3FPLb9UG3VsW-8nfVbK-",
        name = "V10_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 9,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS3588e08b70e293b90143c06f4c7b8f1b5afe950c",
        },
    },
    {
        id = "haeJA4ZU5996BpNFSMu2D",
        name = "V11_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 10,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS1eac7a16f7d2356133a11c30ed1cfc25a5f71229",
        },
    },
    {
        id = "0P-Hgcp8JmmvF7o7ruBM5",
        name = "V12_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 11,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS4c645ceca8f3d4ee8ead639378be705c07b7692f",
        },
    },
    {
        id = "dgPhcTy6G2NPNco8TJjBT",
        name = "V13_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 12,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSf0e6daa0f6f654158be9723ed1c862cedb3cb074",
        },
    },
    {
        id = "glcJ-aIJw_BtgwdA1gc92",
        name = "V14_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 13,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSacc0bd3a37bd607e5cc3267d2f73c2bb53e2ba1e",
        },
    },
    {
        id = "0US_gNl6HQE_r4horXCXn",
        name = "V15_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 14,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSdb7cd88f6a4eeb04bdf368ea9d020504dc42f86f",
        },
    },
    {
        id = "D_XTLXBMT0ujklhHfmLsq",
        name = "V16_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 15,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSf6dd39666432405992d1b844b90fd19ea3fb27b1",
        },
    },
}

local B2_mappings = {
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
}

local mappings = {
    table.unpack(B1_mappings),
    table.unpack(B2_mappings),
    table.unpack(Bank_selectors),
}

local main_compartment = {
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
        mappings = mappings,
    },
}
return main_compartment
