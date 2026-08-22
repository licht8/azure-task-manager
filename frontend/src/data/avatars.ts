export type Avatar = {
  id: number;
  emoji: string;
  label: string;
  tint: string;
};

export const avatars: Avatar[] = [
  { id: 1, emoji: "🦊", label: "Fox", tint: "bg-[oklch(0.93_0.06_60)]" },
  { id: 2, emoji: "🐼", label: "Panda", tint: "bg-[oklch(0.94_0.02_260)]" },
  { id: 3, emoji: "🐨", label: "Koala", tint: "bg-[oklch(0.93_0.03_200)]" },
  { id: 4, emoji: "🦉", label: "Owl", tint: "bg-[oklch(0.93_0.05_80)]" },
  { id: 5, emoji: "🐙", label: "Octopus", tint: "bg-[oklch(0.92_0.05_20)]" },
  { id: 6, emoji: "🦄", label: "Unicorn", tint: "bg-[oklch(0.93_0.05_330)]" },
  { id: 7, emoji: "🐝", label: "Bee", tint: "bg-[oklch(0.94_0.07_95)]" },
  { id: 8, emoji: "🐳", label: "Whale", tint: "bg-[oklch(0.92_0.05_240)]" },
  { id: 9, emoji: "🐢", label: "Turtle", tint: "bg-[oklch(0.93_0.05_150)]" },
  { id: 10, emoji: "🐧", label: "Penguin", tint: "bg-[oklch(0.94_0.02_230)]" },
];

export const getAvatar = (id: number): Avatar => avatars.find((a) => a.id === id) ?? avatars[0]!;
