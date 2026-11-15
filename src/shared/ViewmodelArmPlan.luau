-- IRON YARD / original first-person gloves in hand-local coordinates.
-- Roblox cylinders use their X axis. A 90-degree Y tilt places them
-- along the arm, towards the camera at positive Z.
local Plan = {}

Plan.pieces = {
    { name = "Forearm", shape = "Cylinder", finish = "fabric",
        size = {0.72, 0.28, 0.31}, position = {0, 0.028, 0.425}, angles = {8, 90, 0} },
    { name = "SleeveCuff", shape = "Cylinder", finish = "cuff",
        size = {0.17, 0.254, 0.27}, position = {0, 0.027, 0.125}, angles = {0, 90, 0} },
    { name = "GlovePalm", shape = "Ball", finish = "glove",
        size = {0.291, 0.206, 0.325}, position = {0, 0.006, -0.103} },
    { name = "GloveFingers", shape = "Ball", finish = "finger",
        size = {0.253, 0.135, 0.208}, position = {0.008, -0.052, -0.216}, angles = {21, 0, 0} },
    { name = "GloveThumb", shape = "Ball", finish = "glove",
        size = {0.121, 0.144, 0.218}, position = {-0.115, -0.028, -0.079}, angles = {8, -22, -19} },
    { name = "KnuckleGuard", shape = "Ball", finish = "guard",
        size = {0.214, 0.062, 0.133}, position = {0, 0.103, -0.171}, angles = {14, 0, 0} },
    { name = "WristWebbing", shape = "Cylinder", finish = "webbing",
        size = {0.051, 0.258, 0.276}, position = {0, 0.027, 0.088}, angles = {0, 90, 0} },
    { name = "WristTab", shape = "Block", finish = "tab",
        size = {0.094, 0.031, 0.087}, position = {0.065, 0.153, 0.095}, angles = {4, 0, -16} },
    { name = "SleeveSeam", shape = "Ball", finish = "cuff",
        size = {0.106, 0.023, 0.43}, position = {0.033, 0.174, 0.458}, angles = {8, 0, 0} },
    { name = "SleevePatch", shape = "Ball", finish = "tab",
        size = {0.102, 0.026, 0.143}, position = {-0.051, 0.167, 0.435}, angles = {8, 0, 8} },
}

-- Mirror only the authored coordinates and rotations. No negative scales.
function Plan.pose(piece, left)
    local mirror = left and -1 or 1
    local angle = piece.angles
    return piece.position[1] * mirror, piece.position[2], piece.position[3],
        angle and angle[1] or 0, angle and angle[2] * mirror or 0,
        angle and angle[3] * mirror or 0
end

return Plan
