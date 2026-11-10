"""Original physically modeled IRON YARD long-gun families for Blender weapon forge.

The armatures/first-person animation are still implemented client-side:
each named mechanical component exports as an independent MeshPart.
All meshes use the same world-space origin to preserve aligned CFrames.
"""
from math import pi


def assault_rifle(m, high, box, cylinder, joined):
    armor, metal, carbon, sand = (m[k] for k in ("armor", "gunmetal", "carbon", "accent_sand"))
    q = 3 if high else 1
    base = [
        box("Upper forged receiver", (0, 0, 0.12), (.43, .91, .28), armor, q),
        box("Lower trigger housing", (0, -.20, -.10), (.38, .61, .25), metal, q),
        box("Stock beam", (0, -.85, -.07), (.25, .85, .20), carbon, q),
        box("Stock shoulder pad", (0, -1.30, -.08), (.42, .10, .43), carbon, q),
        box("Pistol grip", (0, -.44, -.33), (.23, .34, .54), carbon, q),
        box("Trigger guard", (0, -.19, -.25), (.33, .35, .055), metal, 1),
        box("Aluminum handguard", (0, .82, .03), (.48, .98, .32), armor, q),
        cylinder("Free-float barrel", (0, 1.73, .06), .092, 1.33, metal, 24 if high else 12),
        cylinder("Muzzle compensator", (0, 2.42, .06), .139, .21, metal, 24 if high else 12),
        cylinder("Gas piston", (0, 1.43, .16), .057, .28, metal, 16 if high else 10),
        box("Receiver ejection port", (.223, .08, .13), (.015, .31, .11), carbon, 0),
        box("Continuous top rail", (0, .43, .32), (.27, 1.70, .06), metal, 1),
        box("Front sight", (0, 1.57, .42), (.18, .08, .17), metal, q),
        box("Rear sight", (0, -.40, .36), (.22, .08, .14), carbon, q),
    ]
    for side in (-1, 1):
        base.append(box("Textured fore-end", (side*.251, .84, .02),
                        (.028, .79, .18), carbon, 1))
    if high:
        for i in range(5):
            base.append(box("CNC rail slot", (0, -.38+i*.36, .363),
                            (.27, .043, .024), carbon, 0))
        for side in (-1, 1):
            for i in range(4):
                base.append(box("Handguard milled vent", (side*.267, .48+i*.23, .04),
                                (.014, .13, .075), carbon, 0))
            base.append(cylinder("Selector detent", (side*.213, -.23, -.04),
                                 .055, .025, sand, 16, axis="Z"))
    joined(base, "IRONYARD_AssaultRifle_Static")

    handle = [
        box("Bilateral charging handle", (0, -.39, .40), (.36, .16, .095), metal, q),
        box("T-shaped cocking tab", (0, -.52, .39), (.42, .10, .075), carbon, 1),
    ]
    joined(handle, "IRONYARD_AssaultRifle_ChargingHandle")
    magazine = [
        box("Curved magazine upper", (0, -.18, -.31), (.29, .28, .33), carbon, q),
        box("Curved magazine lower", (0, -.35, -.57), (.29, .31, .34), metal, q),
        box("Magazine floorplate", (0, -.43, -.75), (.32, .29, .075), sand, q),
    ]
    if high:
        for side in (-1, 1):
            for i in range(3):
                magazine.append(box("Magazine ribs", (side*.151, -.39+i*.12, -.55),
                                    (.012, .045, .30), carbon, 0))
    joined(magazine, "IRONYARD_AssaultRifle_Magazine")


def shotgun(m, high, box, cylinder, joined):
    armor, metal, carbon, sand = (m[k] for k in ("armor", "gunmetal", "carbon", "accent_sand"))
    q = 3 if high else 1
    base = [
        box("Machined receiver", (0, .08, .03), (.53, 1.01, .36), metal, q),
        box("Upper receiver cover", (0, .04, .25), (.44, .71, .09), armor, q),
        box("Pistol grip", (0, -.34, -.28), (.27, .36, .51), carbon, q),
        box("Ribbed shoulder stock", (0, -1.01, -.09), (.36, 1.16, .34), carbon, q),
        box("Shock absorption heel", (0, -1.62, -.08), (.43, .10, .46), sand, q),
        box("Trigger guard", (0, -.13, -.28), (.34, .32, .055), metal, 1),
        cylinder("Full-length bore barrel", (0, 1.28, .19), .128, 2.18, metal, 24 if high else 12),
        cylinder("Magazine tube", (0, 1.30, -.11), .108, 2.12, armor, 20 if high else 12),
        cylinder("Muzzle crown", (0, 2.39, .19), .155, .10, metal, 24 if high else 12),
        box("Loading gate", (0, -.21, -.18), (.28, .26, .022), carbon, 0),
        box("Ejection gate", (.274, .18, .08), (.020, .33, .14), carbon, 0),
        box("Bead front sight", (0, 2.20, .36), (.08, .08, .09), sand, q),
        box("Rear notch", (0, -.31, .33), (.18, .07, .09), carbon, q),
    ]
    if high:
        for side in (-1,1):
            base.append(box("Stock cheek insert", (side*.189, -1.13, .035),
                            (.025, .58, .13), sand, 1))
            for j in range(2):
                base.append(cylinder("Receiver retaining pin", (side*.278,-.18+j*.37,.06),
                                     .038,.026,sand,16,axis="Z"))
        base.append(box("Barrel clamp", (0, 1.83, .04), (.33,.12,.52),armor,q))
    joined(base,"IRONYARD_Shotgun_Static")

    pump = [
        box("Sliding pump furniture", (0, 1.13, -.04), (.57,.85,.31), sand,q),
        box("Pump grip inlay", (0,1.13,-.20), (.40,.73,.055), carbon,1),
    ]
    for side in (-1,1):
        for i in range(3 if high else 1):
            pump.append(box("Angled fore-end groove", (side*.293,.83+i*.21,-.025),
                            (.018,.07,.22),carbon,0))
    joined(pump,"IRONYARD_Shotgun_PumpAction")


def sniper(m, high, box, cylinder, joined):
    armor, metal, carbon, sand = (m[k] for k in ("armor", "gunmetal", "carbon", "accent_sand"))
    q = 3 if high else 1
    base = [
        box("Precision receiver", (0,.12,0), (.43,1.09,.30),armor,q),
        box("Chassis forend", (0,1.12,-.08), (.42,1.03,.22),metal,q),
        box("Adjustable buttstock", (0,-1.17,-.12), (.33,1.12,.27),carbon,q),
        box("Cheekpiece", (0,-1.17,.09), (.31,.54,.14),sand,q),
        box("Butt shoulder pad", (0,-1.80,-.14), (.43,.11,.46), carbon,q),
        box("Vertical pistol grip", (0,-.44,-.30), (.24,.29,.51),carbon,q),
        box("Trigger guard", (0,-.18,-.24), (.35,.29,.06),metal,1),
        cylinder("Heavy fluted barrel", (0,1.93,-.005), .113,2.31,metal,28 if high else 12),
        cylinder("Muzzle brake", (0,3.12,-.005),.16,.19,metal,24 if high else 12),
        box("Scope mounting rail", (0,.26,.34), (.28,1.19,.08),metal,1),
        cylinder("Optic central tube", (0,.28,.57),.19,1.10,carbon,32 if high else 12),
        cylinder("Objective bell", (0,.89,.57),.27,.33,metal,32 if high else 12),
        cylinder("Eyepiece assembly", (0,-.40,.57),.225,.29,metal,24 if high else 12),
        cylinder("Blue glass front", (0,1.064,.57),.23,.02,armor,24 if high else 12),
        cylinder("Elevation turret", (0,.25,.84),.105,.24,sand,20 if high else 10,axis="Z"),
        cylinder("Windage turret", (.20,.25,.57),.105,.16,sand,20 if high else 10,axis="Z"),
    ]
    for i in range(2):
        base.append(box("Optical saddle", (0,-.09+i*.69,.39),(.27,.11,.19),metal,q))
    if high:
        for side in (-1,1):
            base.append(box("Bipod folded rail", (side*.16,1.65,-.30),
                            (.065,.64,.11),metal,q))
            for i in range(4):
                base.append(box("Cooling slot", (side*.222,.80+i*.20,-.05),
                                (.015,.09,.07),carbon,0))
        for i in range(3):
            base.append(box("Muzzle brake port", (0,3.02+i*.06,.16),(.09,.031,.018),
                            carbon,0))
    joined(base,"IRONYARD_Sniper_Static")
    bolt = [
        cylinder("Polished bolt",(.20,.13,.07), .063,.58,metal,20 if high else 10),
        box("Bolt handle stem",(.39,.04,.10),(.32,.085,.075),metal,q),
        cylinder("Bolt spherical knob",(.59,.04,.10),.112,.16,carbon,
                 22 if high else 12,axis="Z"),
    ]
    joined(bolt,"IRONYARD_Sniper_Bolt")
