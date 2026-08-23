export type Avatar = {
  id: number;
  image: string;
  label: string;
  tint: string;
};

export const avatars: Avatar[] = [
  {
    id: 1,
    image: "/avatars/avatar-01.png",
    label: "Fox",
    tint: "bg-[oklch(0.93_0.06_60)]",
  },
  {
    id: 2,
    image: "/avatars/avatar-02.png",
    label: "Panda",
    tint: "bg-[oklch(0.94_0.02_260)]",
  },
  {
    id: 3,
    image: "/avatars/avatar-03.png",
    label: "Koala",
    tint: "bg-[oklch(0.93_0.03_200)]",
  },
  {
    id: 4,
    image: "/avatars/avatar-04.png",
    label: "Owl",
    tint: "bg-[oklch(0.93_0.05_80)]",
  },
  {
    id: 5,
    image: "/avatars/avatar-05.png",
    label: "Octopus",
    tint: "bg-[oklch(0.92_0.05_20)]",
  },
  {
    id: 6,
    image: "/avatars/avatar-06.png",
    label: "Unicorn",
    tint: "bg-[oklch(0.93_0.05_330)]",
  },
  {
    id: 7,
    image: "/avatars/avatar-07.png",
    label: "Bee",
    tint: "bg-[oklch(0.94_0.07_95)]",
  },
  {
    id: 8,
    image: "/avatars/avatar-08.png",
    label: "Whale",
    tint: "bg-[oklch(0.92_0.05_240)]",
  },
  {
    id: 9,
    image: "/avatars/avatar-09.png",
    label: "Turtle",
    tint: "bg-[oklch(0.93_0.05_150)]",
  },
  {
    id: 10,
    image: "/avatars/avatar-10.png",
    label: "Penguin",
    tint: "bg-[oklch(0.94_0.02_230)]",
  },
];

export const getAvatar = (id: number): Avatar =>
  avatars.find((a) => a.id === id) ?? avatars[0]!;