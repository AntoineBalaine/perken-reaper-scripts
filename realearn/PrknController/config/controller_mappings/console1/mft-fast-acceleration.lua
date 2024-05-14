local version = {
  version= "2.15.0",
  name= "MFT fast acceleration",
  defaultGroup= {},
  groups= {
    {
      id= "S4vSFtoLZyctXfOkWqd_7",
      name= "BANK1",
      activationType= "program"
    },
    {
      id= "o4DaBaqXAgKHOezxw0fFl",
      name= "BANK2",
      activationType= "program",
      programCondition= {
        paramIndex= 0,
        programIndex= 1
      }
    },
    {
      id= "1W2CM4HFJT2vuuPXu5fn_",
      name= "dummies"
    }
  },
  mappings= {
    {
      id= "GKr6XIMDomfdBvdUgBWq2",
      name= "V1_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual"
      },
      mode= {
        maxStepSize= 0.71,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 00 10"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "3tICfLtgYaMUrEtRF-j0-",
      name= "V2_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 1
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 6,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 01 10"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "VEGCtvC7As8JvuwAT7MDL",
      name= "V3_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 2
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 9,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 02 10"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "f6s6xksXI1P5ORtfttJUQ",
      name= "V4_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 3
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 1,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 03 10"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "O1TA84rxsfsXcWa9mt2gZ",
      name= "V5_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 4
      },
      mode= {
        minStepSize= 0.0,
        maxStepSize= 0.38,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 1,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 04 33"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "3oGY61kvfdZkxdErl6YKW",
      name= "V6_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 5
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 2,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 05 33"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "T3ykjm7UmcEmWYhmrjl7i",
      name= "V7_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 6
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 3,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 06 33"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "T0PYrvAkeHortwH7pppcf",
      name= "V8_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 7
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 4,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 07 33"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "1NXUfzIkeBH4g6bKDwPIC",
      name= "V9_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 8
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 9,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 08 62"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "T3FPLb9UG3VsW-8nfVbK-",
      name= "V10_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 9
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 10,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 09 62"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "haeJA4ZU5996BpNFSMu2D",
      name= "V11_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 10
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        fxAnchor= "instance",
        useSelectionGanging= false,
        useTrackGrouping= false,
        paramIndex= 3,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 0A 62"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "0P-Hgcp8JmmvF7o7ruBM5",
      name= "V12_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 11
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        type= 0,
        commandName= "RS4c645ceca8f3d4ee8ead639378be705c07b7692f",
        fxAnchor= "id",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 0B 62"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "dgPhcTy6G2NPNco8TJjBT",
      name= "V13_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 12
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        type= 0,
        commandName= "RSf0e6daa0f6f654158be9723ed1c862cedb3cb074",
        fxAnchor= "id",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 0C 2C"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "glcJ-aIJw_BtgwdA1gc92",
      name= "V14_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 13
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        type= 0,
        commandName= "RSacc0bd3a37bd607e5cc3267d2f73c2bb53e2ba1e",
        fxAnchor= "id",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 0D 2C"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "0US_gNl6HQE_r4horXCXn",
      name= "V15_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 14
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        type= 0,
        commandName= "RSdb7cd88f6a4eeb04bdf368ea9d020504dc42f86f",
        fxAnchor= "id",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 0E 2C"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "D_XTLXBMT0ujklhHfmLsq",
      name= "V16_B1",
      tags= {
        "b1"
      },
      groupId= "S4vSFtoLZyctXfOkWqd_7",
      source= {
        category= "virtual",
        controlElementIndex= 15
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        type= 0,
        commandName= "RSf6dd39666432405992d1b844b90fd19ea3fb27b1",
        fxAnchor= "id",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 0F 2C"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "xymAWh9XDME-gCzIVUdYq",
      name= "V1_B2",
      groupId= "o4DaBaqXAgKHOezxw0fFl",
      source= {
        category= "virtual"
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000
      },
      target= {
        type= 0,
        commandName= "RS830a2f5bc01f783a8420b014d40d85ce347e6f9b",
        fxAnchor= "id",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 00 03"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "05qt6I1vMb2VAB_iIcA4u",
      name= "B1_Select",
      source= {
        category= "virtual",
        controlElementType= "button",
        controlElementIndex= "bank-left"
      },
      mode= {
        maxTargetValue= 0.0,
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000,
        outOfRangeBehavior= "min"
      },
      target= {
        fxAnchor= "this",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 00 10 B1 01 10 B1 02 10 B1 03 10 B1 04 33 B1 05 33 B1 06 33 B1 07 33 B1 08 62 B1 09 62 B1 0A 62 B1 0B 62 B1 0C 2C B1 0D 2C B1 0E 2C B1 0F 2C"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "a2y2AMUJMsKwoxsijcLXM",
      name= "B2_Select",
      source= {
        category= "virtual",
        controlElementType= "button",
        controlElementIndex= "bank-right"
      },
      mode= {
        minSourceValue= 0.01,
        maxSourceValue= 0.01,
        minTargetValue= 0.01,
        maxTargetValue= 0.01,
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 1
      },
      target= {
        fxAnchor= "this",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      }
    },
    {
      id= "yrG1get-yMWFTT-EYpCzt",
      name= "COLORS",
      tags= {
        "select"
      },
      source= {
        category= "never"
      },
      mode= {
        maxSourceValue= 0.01,
        minTargetValue= 0.01,
        maxTargetValue= 0.01,
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 1
      },
      target= {
        type= 53,
        fxAnchor= "id",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        }
      },
      isEnabled= false,
      controlIsEnabled= false,
      advanced= {
        on_activate= {
          send_midi_feedback= {
            {
              raw= "B1 00 4F B1 01 4F B1 02 4F B1 03 4F B1 04 4F B1 05 4F B1 06 4F B1 07 4F B1 08 4F B1 09 4F B1 0A 4F B1 0B 4F B1 0C 4F B1 0D 4F B1 0E 4F B1 0F 4F"
            }
          }
        },
        on_deactivate= {
          send_midi_feedback= {}
        }
      }
    },
    {
      id= "GsGIrpIfvaAGLA66FXl8E",
      name= "Enable_selectTag",
      groupId= "1W2CM4HFJT2vuuPXu5fn_",
      source= {
        category= "virtual",
        controlElementType= "button",
        controlElementIndex= 12
      },
      mode= {
        maxStepSize= 0.05,
        minStepFactor= 1,
        maxStepFactor= 3000,
        outOfRangeBehavior= "ignore"
      },
      target= {
        type= 36,
        fxAnchor= "id",
        useSelectionGanging= false,
        useTrackGrouping= false,
        seekBehavior= "Immediate",
        mouseAction= {
          kind= "MoveTo",
          axis= "Y"
        },
        pollForFeedback= false,
        tags= {
          "select"
        },
        takeMappingSnapshot= {
          kind= "ById",
          id= ""
        },
        exclusivity= 1
      }
    }
  }
}
