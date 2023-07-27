return {
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
      {
        id = "1W2CM4HFJT2vuuPXu5fn_",
        name = "dummies",
      },
    },
    mappings = {
      {

        kind = "Mapping",
        version = "2.16.0-pre.1",
        value = {
          id = "GKr6XIMDomfdBvdUgBWq2",
          name = "V1_B1",
          tags = {
            "b1",
          },
          group = "S4vSFtoLZyctXfOkWqd_7",
          on_activate = {
            send_midi_feedback = {
              {
                kind = "Raw",
                message = "B1 00 10",
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
      }
      ,
      {
        id = "xymAWh9XDME-gCzIVUdYq",
        name = "V1_B2",
        group = "o4DaBaqXAgKHOezxw0fFl",
        on_activate = {
          send_midi_feedback = {
            {
              kind = "Raw",
              message = "B1 00 03",
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
      {
        id = "yrG1get-yMWFTT-EYpCzt",
        name = "COLORS",
        tags = {
          "select",
        },
        control_enabled = false,
        on_activate = {
          send_midi_feedback = {
            {
              kind = "Raw",
              message =
              "B1 00 4F B1 01 4F B1 02 4F B1 03 4F B1 04 4F B1 05 4F B1 06 4F B1 07 4F B1 08 4F B1 09 4F B1 0A 4F B1 0B 4F B1 0C 4F B1 0D 4F B1 0E 4F B1 0F 4F",
            },
          },
        },
        glue = {
          source_interval = { 0, 0.01 },
          target_interval = { 0.01, 0.01 },
          step_size_interval = { 0.01, 0.05 },
        },
        target = {
          kind = "Dummy",
        },
      },
      {
        id = "GsGIrpIfvaAGLA66FXl8E",
        name = "Enable_selectTag",
        group = "1W2CM4HFJT2vuuPXu5fn_",
        source = {
          kind = "Virtual",
          id = 12,
          character = "Button",
        },
        glue = {
          out_of_range_behavior = "Ignore",
          step_size_interval = { 0.01, 0.05 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "EnableMappings",
          tags = {
            "select",
          },
          exclusivity = "Exclusive",
        },
      },
      {
        id = "3xQoYggImQyCCrPe381d7",
        name = "22",
        enabled = false,
        glue = {
          step_size_interval = { 0.01, 0.05 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Dummy",
        },
      },
    },
  },
}
