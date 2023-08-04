-- @noindex
---@type Compartment
local MFT_controller_compartment = {
  kind = "ControllerCompartment",
  version = "2.15.0",
  value = {
    groups = {
      {
        id = "1b0ae2b7-d905-456c-861d-fa3f2c886795",
        name = "Side buttons",
      },
      {
        id = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        name = "Push encoders",
      },
    },
    mappings = {
      {
        id = "0c029363-71c7-4115-b8e0-7245ac1b6d4b",
        name = "Encoder 1/1",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 0,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 0,
        },
      },
      {
        id = "e5543ad8-9e81-4baf-a82d-2c281445e705",
        name = "Button 1/1",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 0,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 0,
          character = "Button",
        },
      },
      {
        id = "27521ef0-5cf8-45e9-9c90-4d4906cf6304",
        name = "Encoder 1/2",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 1,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 1,
        },
      },
      {
        id = "dd1a81d3-d607-4329-9d91-a6b888b0faaf",
        name = "Button 1/2",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 1,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 1,
          character = "Button",
        },
      },
      {
        id = "54a066e2-48e3-4653-9fbb-ef907db09d87",
        name = "Encoder 1/3",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 2,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 2,
        },
      },
      {
        id = "b82d7752-d229-448f-bd42-af61b459e481",
        name = "Button 1/3",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 2,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 2,
          character = "Button",
        },
      },
      {
        id = "a3c27c02-c52d-471c-b706-27b62e2a5dbe",
        name = "Encoder 1/4",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 3,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 3,
        },
      },
      {
        id = "1c86e131-a1b9-4e4c-91d5-18ca2404cc88",
        name = "Button 1/4",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 3,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 3,
          character = "Button",
        },
      },
      {
        id = "828d465a-9bd3-4436-9134-488a6feb1fbf",
        name = "Encoder 2/1",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 4,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 4,
        },
      },
      {
        id = "50f3d56d-0f63-4086-9592-b3ce913db381",
        name = "Button 2/1",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 4,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 4,
          character = "Button",
        },
      },
      {
        id = "7190e2a6-e07c-4922-9bb4-d6d2b072d801",
        name = "Encoder 2/2",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 5,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 5,
        },
      },
      {
        id = "039f799b-537f-4277-abc1-03c506827083",
        name = "Button 2/2",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 5,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 5,
          character = "Button",
        },
      },
      {
        id = "45bbbd5d-34f7-4ab8-b496-eeb9cf602a78",
        name = "Encoder 2/3",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 6,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 6,
        },
      },
      {
        id = "cd973603-c9b7-4ab0-9817-205576531ef1",
        name = "Button 2/3",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 6,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 6,
          character = "Button",
        },
      },
      {
        id = "d2849ec7-c895-44ee-bffa-34eef50f977c",
        name = "Encoder 2/4",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 7,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 7,
        },
      },
      {
        id = "8018c259-6f76-4133-9047-6410781896ad",
        name = "Button 2/4",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 7,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 7,
          character = "Button",
        },
      },
      {
        id = "25b83ec2-54da-4c0a-8415-880a30ef6a1f",
        name = "Encoder 3/1",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 8,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 8,
        },
      },
      {
        id = "16013c48-2a49-4672-bf3a-95eae05ef3a7",
        name = "Button 3/1",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 8,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 8,
          character = "Button",
        },
      },
      {
        id = "640eb2a4-735d-4d91-ae5b-63671dfab5d7",
        name = "Encoder 3/2",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 9,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 9,
        },
      },
      {
        id = "2e187a1d-fad0-47e4-8b89-d96b94500032",
        name = "Button 3/2",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 9,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 9,
          character = "Button",
        },
      },
      {
        id = "c865c503-25fc-4b81-bbc8-0731105a2656",
        name = "Encoder 3/3",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 10,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 10,
        },
      },
      {
        id = "f7a9305d-94ab-4fc9-9b64-a909e559354b",
        name = "Button 3/3",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 10,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 10,
          character = "Button",
        },
      },
      {
        id = "7a5f1680-f5ed-463b-979d-b30916e3bb3a",
        name = "Encoder 3/4",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 11,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 11,
        },
      },
      {
        id = "6b8ad131-bed9-4ba7-a604-435cf0436c91",
        name = "Button 3/4",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 11,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 11,
          character = "Button",
        },
      },
      {
        id = "3b5fc1e8-42db-4581-947e-5dfa3d3c0bf4",
        name = "Encoder 4/1",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 12,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 12,
        },
      },
      {
        id = "1c091580-986f-42fe-8942-759d81df18b2",
        name = "Button 4/1",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 12,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 12,
          character = "Button",
        },
      },
      {
        id = "a38435c0-3ac4-4174-b1b1-781eff7988c4",
        name = "Encoder 4/2",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 13,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 13,
        },
      },
      {
        id = "9145b8a7-021e-46e9-bc24-588b5b70e3cd",
        name = "Button 4/2",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 13,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 13,
          character = "Button",
        },
      },
      {
        id = "9406038e-3c44-432d-8ecc-3f41540ae0c8",
        name = "Encoder 4/3",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 14,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 14,
        },
      },
      {
        id = "232d989a-e0d7-47f9-9587-668ac12584a3",
        name = "Button 4/3",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 14,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 14,
          character = "Button",
        },
      },
      {
        id = "55aa23b0-b820-4ebe-9b12-9fe40842ef27",
        name = "Encoder 4/4",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 0,
          controller_number = 15,
          character = "Relative2",
        },
        glue = {
          step_size_interval = { 0.01, 1 },
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 15,
        },
      },
      {
        id = "6772a9e3-288b-4f4b-a0ae-3bce83009d4d",
        name = "Button 4/4",
        group = "c37662ef-631e-4ccf-a62b-08baab2167f9",
        source = {
          kind = "MidiControlChangeValue",
          channel = 1,
          controller_number = 15,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = 15,
          character = "Button",
        },
      },
      {
        id = "27bf2152-e7f4-45e5-9b98-dcae8965b91f",
        name = "Upper left",
        group = "1b0ae2b7-d905-456c-861d-fa3f2c886795",
        feedback_enabled = false,
        source = {
          kind = "MidiControlChangeValue",
          channel = 3,
          controller_number = 8,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = "bank-left",
          character = "Button",
        },
      },
      {
        id = "ee9df590-61cb-4746-a313-77356e58b35e",
        name = "Upper right",
        group = "1b0ae2b7-d905-456c-861d-fa3f2c886795",
        feedback_enabled = false,
        source = {
          kind = "MidiControlChangeValue",
          channel = 3,
          controller_number = 11,
          character = "Button",
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = "bank-right",
          character = "Button",
        },
      },
      {
        id = "ab054880-1c43-4f4a-b418-c3ea4d31b510",
        name = "Lower left",
        group = "1b0ae2b7-d905-456c-861d-fa3f2c886795",
        feedback_enabled = false,
        source = {
          kind = "MidiControlChangeValue",
          channel = 3,
          controller_number = 10,
          character = "Button",
          fourteen_bit = false,
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = "ch-left",
          character = "Button",
        },
      },
      {
        id = "a57a2787-3919-46fb-8fdd-17fb83f4baf1",
        name = "Lower right",
        group = "1b0ae2b7-d905-456c-861d-fa3f2c886795",
        feedback_enabled = false,
        source = {
          kind = "MidiControlChangeValue",
          channel = 3,
          controller_number = 13,
          character = "Button",
          fourteen_bit = false,
        },
        glue = {
          step_factor_interval = { 1, 5 },
        },
        target = {
          kind = "Virtual",
          id = "ch-right",
          character = "Button",
        },
      },
    },
    custom_data = {
      companion = {
        controls = {
          {
            height = 50,
            id = "a3c27c02-c52d-471c-b706-27b62e2a5dbe",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "a3c27c02-c52d-471c-b706-27b62e2a5dbe",
              "1c86e131-a1b9-4e4c-91d5-18ca2404cc88",
            },
            shape = "circle",
            width = 50,
            x = 400,
            y = 0,
          },
          {
            height = 50,
            id = "828d465a-9bd3-4436-9134-488a6feb1fbf",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "828d465a-9bd3-4436-9134-488a6feb1fbf",
              "50f3d56d-0f63-4086-9592-b3ce913db381",
            },
            shape = "circle",
            width = 50,
            x = 100,
            y = 100,
          },
          {
            height = 50,
            id = "d2849ec7-c895-44ee-bffa-34eef50f977c",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "d2849ec7-c895-44ee-bffa-34eef50f977c",
              "8018c259-6f76-4133-9047-6410781896ad",
            },
            shape = "circle",
            width = 50,
            x = 400,
            y = 100,
          },
          {
            height = 50,
            id = "0c029363-71c7-4115-b8e0-7245ac1b6d4b",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "0c029363-71c7-4115-b8e0-7245ac1b6d4b",
              "e5543ad8-9e81-4baf-a82d-2c281445e705",
            },
            shape = "circle",
            width = 50,
            x = 100,
            y = 0,
          },
          {
            height = 50,
            id = "54a066e2-48e3-4653-9fbb-ef907db09d87",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "54a066e2-48e3-4653-9fbb-ef907db09d87",
              "b82d7752-d229-448f-bd42-af61b459e481",
            },
            shape = "circle",
            width = 50,
            x = 300,
            y = 0,
          },
          {
            height = 50,
            id = "27521ef0-5cf8-45e9-9c90-4d4906cf6304",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "27521ef0-5cf8-45e9-9c90-4d4906cf6304",
              "dd1a81d3-d607-4329-9d91-a6b888b0faaf",
            },
            shape = "circle",
            width = 50,
            x = 200,
            y = 0,
          },
          {
            height = 50,
            id = "7190e2a6-e07c-4922-9bb4-d6d2b072d801",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "7190e2a6-e07c-4922-9bb4-d6d2b072d801",
              "039f799b-537f-4277-abc1-03c506827083",
            },
            shape = "circle",
            width = 50,
            x = 200,
            y = 100,
          },
          {
            height = 50,
            id = "45bbbd5d-34f7-4ab8-b496-eeb9cf602a78",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "45bbbd5d-34f7-4ab8-b496-eeb9cf602a78",
              "cd973603-c9b7-4ab0-9817-205576531ef1",
            },
            shape = "circle",
            width = 50,
            x = 300,
            y = 100,
          },
          {
            height = 50,
            id = "640eb2a4-735d-4d91-ae5b-63671dfab5d7",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "640eb2a4-735d-4d91-ae5b-63671dfab5d7",
              "2e187a1d-fad0-47e4-8b89-d96b94500032",
            },
            shape = "circle",
            width = 50,
            x = 200,
            y = 200,
          },
          {
            height = 50,
            id = "c865c503-25fc-4b81-bbc8-0731105a2656",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "c865c503-25fc-4b81-bbc8-0731105a2656",
              "f7a9305d-94ab-4fc9-9b64-a909e559354b",
            },
            shape = "circle",
            width = 50,
            x = 300,
            y = 200,
          },
          {
            height = 50,
            id = "55aa23b0-b820-4ebe-9b12-9fe40842ef27",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "55aa23b0-b820-4ebe-9b12-9fe40842ef27",
              "6772a9e3-288b-4f4b-a0ae-3bce83009d4d",
            },
            shape = "circle",
            width = 50,
            x = 400,
            y = 300,
          },
          {
            height = 50,
            id = "3b5fc1e8-42db-4581-947e-5dfa3d3c0bf4",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "3b5fc1e8-42db-4581-947e-5dfa3d3c0bf4",
              "1c091580-986f-42fe-8942-759d81df18b2",
            },
            shape = "circle",
            width = 50,
            x = 100,
            y = 300,
          },
          {
            height = 50,
            id = "a38435c0-3ac4-4174-b1b1-781eff7988c4",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "a38435c0-3ac4-4174-b1b1-781eff7988c4",
              "9145b8a7-021e-46e9-bc24-588b5b70e3cd",
            },
            shape = "circle",
            width = 50,
            x = 200,
            y = 300,
          },
          {
            height = 50,
            id = "9406038e-3c44-432d-8ecc-3f41540ae0c8",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "9406038e-3c44-432d-8ecc-3f41540ae0c8",
              "232d989a-e0d7-47f9-9587-668ac12584a3",
            },
            shape = "circle",
            width = 50,
            x = 300,
            y = 300,
          },
          {
            height = 50,
            id = "25b83ec2-54da-4c0a-8415-880a30ef6a1f",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "25b83ec2-54da-4c0a-8415-880a30ef6a1f",
              "16013c48-2a49-4672-bf3a-95eae05ef3a7",
            },
            shape = "circle",
            width = 50,
            x = 100,
            y = 200,
          },
          {
            height = 50,
            id = "7a5f1680-f5ed-463b-979d-b30916e3bb3a",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "center",
              sizeConstrained = true,
            },
            mappings = {
              "7a5f1680-f5ed-463b-979d-b30916e3bb3a",
              "6b8ad131-bed9-4ba7-a604-435cf0436c91",
            },
            shape = "circle",
            width = 50,
            x = 400,
            y = 200,
          },
          {
            height = 50,
            id = "ee9df590-61cb-4746-a313-77356e58b35e",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "belowBottom",
              sizeConstrained = true,
            },
            mappings = {
              "ee9df590-61cb-4746-a313-77356e58b35e",
            },
            shape = "rectangle",
            width = 50,
            x = 500,
            y = 50,
          },
          {
            height = 50,
            id = "27bf2152-e7f4-45e5-9b98-dcae8965b91f",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "belowBottom",
              sizeConstrained = true,
            },
            mappings = {
              "27bf2152-e7f4-45e5-9b98-dcae8965b91f",
            },
            shape = "rectangle",
            width = 50,
            x = 0,
            y = 50,
          },
          {
            height = 50,
            id = "a78b277e-cfbf-4b2b-9cc6-1a550aeb87fd",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "belowBottom",
              sizeConstrained = true,
            },
            mappings = {
              "ab054880-1c43-4f4a-b418-c3ea4d31b510",
            },
            shape = "rectangle",
            width = 50,
            x = 0,
            y = 250,
          },
          {
            height = 50,
            id = "e312d2a2-ecf1-4189-95af-4174c43a750c",
            labelOne = {
              angle = 0,
              position = "aboveTop",
              sizeConstrained = true,
            },
            labelTwo = {
              angle = 0,
              position = "belowBottom",
              sizeConstrained = true,
            },
            mappings = {
              "a57a2787-3919-46fb-8fdd-17fb83f4baf1",
            },
            shape = "rectangle",
            width = 50,
            x = 500,
            y = 250,
          },
        },
        gridDivisionCount = 2,
        gridSize = 50,
      },
    },
  },
}

return MFT_controller_compartment
