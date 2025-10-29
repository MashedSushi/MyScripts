export type Character = Model & {
    Head: BasePart,
    Torso: BasePart,

    LeftArm: BasePart,
    RightArm: BasePart,

    LeftLeg: BasePart,
    RightLeg: BasePart,

    BodyColors: BodyColors,

    HumanoidRootPart: BasePart & {
        RootJoint: Motor6D
    },

    Humanoid: Humanoid & {
        Animator: Animator,
        AnimationController: AnimationController
    },
}

return {}