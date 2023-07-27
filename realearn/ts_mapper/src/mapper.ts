/* Bank 1 colors */
const B1_colors = `
    B1 00 10
    B1 01 10
    B1 02 10
    B1 03 10
    B1 04 33
    B1 05 33
    B1 06 33
    B1 07 33
    B1 08 62
    B1 09 62
    B1 0A 62
    B1 0B 62
    B1 0C 2C
    B1 0D 2C
    B1 0E 2C
    B1 0F 2C `;
const B2_colors = `
    B1 00 03
    B1 01 03
    B1 02 03
    B1 03 03
    B1 04 65
    B1 05 65
    B1 06 65
    B1 07 65
    B1 08 45
    B1 09 45
    B1 0A 45
    B1 0B 45
    B1 0C 4F
    B1 0D 4F
    B1 0E 4F
    B1 0F 4F `;
const tag_select_colors = `
    B1 00 4F
    B1 01 4F
    B1 02 4F
    B1 03 4F
    B1 04 4F
    B1 05 4F
    B1 06 4F
    B1 07 4F
    B1 08 4F
    B1 09 4F
    B1 0A 4F
    B1 0B 4F
    B1 0C 4F
    B1 0D 4F
    B1 0E 4F
    B1 0F 4F `;

const mapping_groups = [
  {
    id: "S4vSFtoLZyctXfOkWqd_7",
    name: "BANK1",
    activationType: "program",
  },
  {
    id: "o4DaBaqXAgKHOezxw0fFl",
    name: "BANK2",
    activationType: "program",
    programCondition: {
      paramIndex: 0,
      programIndex: 1,
    },
  },
  {
    id: "1W2CM4HFJT2vuuPXu5fn_",
    name: "dummies",
  },
];

const tag_selector = {
  id: "GsGIrpIfvaAGLA66FXl8E",
  name: "Enable_selectTag",
  groupId: "1W2CM4HFJT2vuuPXu5fn_",
  source: {
    category: "virtual",
    controlElementType: "button",
    controlElementIndex: 12,
  },
  mode: {
    maxStepSize: 0.05,
    minStepFactor: 1,
    maxStepFactor: 5,
    outOfRangeBehavior: "ignore",
  },
  target: {
    type: 36,
    fxAnchor: "id",
    useSelectionGanging: false,
    useTrackGrouping: false,
    seekBehavior: "Immediate",
    mouseAction: {
      kind: "MoveTo",
      axis: "Y",
    },
    pollForFeedback: false,
    tags: ["select"],
    takeMappingSnapshot: {
      kind: "ById",
      id: "",
    },
    exclusivity: 1,
  },
};

const color_dummy_select_tag = {
  id: "yrG1get-yMWFTT-EYpCzt",
  name: "COLORS",
  tags: ["select"],
  source: {
    category: "never",
  },
  mode: {
    maxSourceValue: 0.01,
    minTargetValue: 0.01,
    maxTargetValue: 0.01,
    maxStepSize: 0.05,
    minStepFactor: 1,
    maxStepFactor: 1,
  },
  target: {
    type: 53,
    fxAnchor: "id",
    useSelectionGanging: false,
    useTrackGrouping: false,
    seekBehavior: "Immediate",
    mouseAction: {
      kind: "MoveTo",
      axis: "Y",
    },
    pollForFeedback: false,
    takeMappingSnapshot: {
      kind: "ById",
      id: "",
    },
  },
  controlIsEnabled: false,
  advanced: {
    on_activate: {
      send_midi_feedback: [
        {
          raw: tag_select_colors,
        },
      ],
    },
    on_deactivate: {
      send_midi_feedback: [],
    },
  },
};

const B2_select_btn = {
  id: "a2y2AMUJMsKwoxsijcLXM",
  name: "B2_Select",
  source: {
    category: "virtual",
    controlElementType: "button",
    controlElementIndex: "bank-right",
  },
  mode: {
    minSourceValue: 0.01,
    maxSourceValue: 0.01,
    minTargetValue: 0.01,
    maxTargetValue: 0.01,
    maxStepSize: 0.05,
    minStepFactor: 1,
    maxStepFactor: 1,
  },
  target: {
    fxAnchor: "this",
    useSelectionGanging: false,
    useTrackGrouping: false,
    seekBehavior: "Immediate",
    mouseAction: {
      kind: "MoveTo",
      axis: "Y",
    },
    takeMappingSnapshot: {
      kind: "ById",
      id: "",
    },
  },
};

const B1_select_btn = {
  id: "05qt6I1vMb2VAB_iIcA4u",
  name: "B1_Select",
  source: {
    category: "virtual",
    controlElementType: "button",
    controlElementIndex: "bank-left",
  },
  mode: {
    maxTargetValue: 0.0,
    maxStepSize: 0.05,
    minStepFactor: 1,
    maxStepFactor: 5,
    outOfRangeBehavior: "min",
  },
  target: {
    fxAnchor: "this",
    useSelectionGanging: false,
    useTrackGrouping: false,
    seekBehavior: "Immediate",
    mouseAction: {
      kind: "MoveTo",
      axis: "Y",
    },
    takeMappingSnapshot: {
      kind: "ById",
      id: "",
    },
  },
  advanced: {
    on_activate: {
      send_midi_feedback: [
        {
          raw: "B1 00 10 B1 01 10 B1 02 10 B1 03 10 B1 04 33 B1 05 33 B1 06 33 B1 07 33 B1 08 62 B1 09 62 B1 0A 62 B1 0B 62 B1 0C 2C B1 0D 2C B1 0E 2C B1 0F 2C",
        },
      ],
    },
    on_deactivate: {
      send_midi_feedback: [],
    },
  },
};

const Bank2 = [
  {
    id: "xymAWh9XDME-gCzIVUdYq",
    name: "V1_B2",
    groupId: "o4DaBaqXAgKHOezxw0fFl",
    source: {
      category: "virtual",
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS830a2f5bc01f783a8420b014d40d85ce347e6f9b",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
    advanced: {
      on_activate: {
        send_midi_feedback: [
          {
            raw: "B1 00 03",
          },
        ],
      },
      on_deactivate: {
        send_midi_feedback: [],
      },
    },
  },
];

let advanced = (color: string) => ({
  on_activate: {
    send_midi_feedback: [
      {
        raw: color,
      },
    ],
  },
  on_deactivate: {
    send_midi_feedback: [],
  },
});

const Bank1 = [
  {
    id: "GKr6XIMDomfdBvdUgBWq2",
    name: "V1_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS86a658f69fadfd0c116968a473ed6b519f4c58cd",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "3tICfLtgYaMUrEtRF-j0-",
    name: "V2_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 1,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS830a2f5bc01f783a8420b014d40d85ce347e6f9b",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "VEGCtvC7As8JvuwAT7MDL",
    name: "V3_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 2,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS7ad216177f674727876f6db23cd4ec198c041924",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "f6s6xksXI1P5ORtfttJUQ",
    name: "V4_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 3,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RScad496a247fdbb534da3a99df0b31f12c6195699",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "O1TA84rxsfsXcWa9mt2gZ",
    name: "V5_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 4,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS32313842f86d8a75dd381cd4a388d9c9101142d9",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "3oGY61kvfdZkxdErl6YKW",
    name: "V6_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 5,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS616a6d79328be95d99b095362456360bce9573dc",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "T3ykjm7UmcEmWYhmrjl7i",
    name: "V7_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 6,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RSb9c4a112e8da743767779d4ef215fda6e77f7944",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "T0PYrvAkeHortwH7pppcf",
    name: "V8_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 7,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS5e00b697a621faca3c972d40b8490d284d28eba2",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "1NXUfzIkeBH4g6bKDwPIC",
    name: "V9_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 8,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RSdc0e41cf2f89ed30e2937a6966919cd3b39c5525",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "T3FPLb9UG3VsW-8nfVbK-",
    name: "V10_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 9,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS3588e08b70e293b90143c06f4c7b8f1b5afe950c",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "haeJA4ZU5996BpNFSMu2D",
    name: "V11_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 10,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS1eac7a16f7d2356133a11c30ed1cfc25a5f71229",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "0P-Hgcp8JmmvF7o7ruBM5",
    name: "V12_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 11,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RS4c645ceca8f3d4ee8ead639378be705c07b7692f",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "dgPhcTy6G2NPNco8TJjBT",
    name: "V13_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 12,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RSf0e6daa0f6f654158be9723ed1c862cedb3cb074",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "glcJ-aIJw_BtgwdA1gc92",
    name: "V14_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 13,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RSacc0bd3a37bd607e5cc3267d2f73c2bb53e2ba1e",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "0US_gNl6HQE_r4horXCXn",
    name: "V15_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 14,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RSdb7cd88f6a4eeb04bdf368ea9d020504dc42f86f",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
  {
    id: "D_XTLXBMT0ujklhHfmLsq",
    name: "V16_B1",
    groupId: "S4vSFtoLZyctXfOkWqd_7",
    source: {
      category: "virtual",
      controlElementIndex: 15,
    },
    mode: {
      maxStepSize: 0.05,
      minStepFactor: 1,
      maxStepFactor: 5,
    },
    target: {
      type: 0,
      commandName: "RSf6dd39666432405992d1b844b90fd19ea3fb27b1",
      fxAnchor: "id",
      useSelectionGanging: false,
      useTrackGrouping: false,
      seekBehavior: "Immediate",
      mouseAction: {
        kind: "MoveTo",
        axis: "Y",
      },
      pollForFeedback: false,
      takeMappingSnapshot: {
        kind: "ById",
        id: "",
      },
    },
  },
].map((mapping, index) => {
  return {
    ...mapping,
    tag: ["b1"],
    advanced: advanced(B1_colors.trim().split("\n")[index]),
  };
});

const mappings = [
  ...Bank1,
  ...Bank2,
  B1_select_btn,
  B2_select_btn,
  color_dummy_select_tag,
  tag_selector,
];

let MainCompartment = {
  kind: "MainCompartment",
  version: "2.16.0-pre.1",
  value: {
    defaultGroup: {},
    groups: mapping_groups,
    mappings: mappings,
  },
};

//import fs
const fs = require("fs");
const path = require("path");

// print main compartment to JSON file
fs.writeFileSync(
  path.join(__dirname, "main_compartment.json"),
  JSON.stringify(MainCompartment, null, 2)
);
