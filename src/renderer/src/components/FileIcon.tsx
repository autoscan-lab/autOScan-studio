import type { IconType } from "react-icons";
import {
  VscFolder,
  VscFolderOpened,
  VscJson,
  VscMarkdown,
  VscSettingsGear,
} from "react-icons/vsc";
import {
  TbBracketsAngle,
  TbFileCode,
  TbFileDescription,
  TbFileLambda,
  TbFileText,
  TbFiles,
} from "react-icons/tb";
import { SiC } from "react-icons/si";

type FileIconProps = {
  name: string;
  isDirectory?: boolean;
  isOpen?: boolean;
  size?: number;
  className?: string;
};

type IconConfig = {
  icon: IconType;
  className: string;
};

function getFileIcon(
  name: string,
  isDirectory?: boolean,
  isOpen?: boolean,
): IconConfig {
  if (isDirectory) {
    return {
      icon: isOpen ? VscFolderOpened : VscFolder,
      className: isOpen ? "text-[#58a6ff]" : "text-[#79c0ff]",
    };
  }

  const lowerName = name.toLowerCase();
  const ext = lowerName.includes(".") ? (lowerName.split(".").pop() ?? "") : "";

  if (lowerName === "makefile" || lowerName === "gnumakefile" || ext === "mk") {
    return {
      icon: VscSettingsGear,
      className: "text-[#d29922]",
    };
  }

  if (ext === "c" || ext === "h") {
    return {
      icon: SiC,
      className: ext === "h" ? "text-[#d2a8ff]" : "text-[#79c0ff]",
    };
  }

  if (ext === "cpp" || ext === "cc" || ext === "cxx" || ext === "hpp") {
    return {
      icon: TbFileCode,
      className: "text-[#79c0ff]",
    };
  }

  if (ext === "md" || ext === "markdown") {
    return {
      icon: VscMarkdown,
      className: "text-[#f0f6fc]",
    };
  }

  if (ext === "yaml" || ext === "yml") {
    return {
      icon: TbFileLambda,
      className: "text-[#7ee787]",
    };
  }

  if (ext === "json") {
    return {
      icon: VscJson,
      className: "text-[#7ee787]",
    };
  }

  if (ext === "txt" || ext === "log") {
    return {
      icon: TbFileText,
      className: "text-[#9198a1]",
    };
  }

  if (ext === "a" || ext === "so" || ext === "dylib") {
    return {
      icon: TbFiles,
      className: "text-[#d29922]",
    };
  }

  return {
    icon: TbFileDescription,
    className: "text-[#9198a1]",
  };
}

export function FileIcon({
  name,
  isDirectory = false,
  isOpen = false,
  size = 15,
  className = "",
}: FileIconProps) {
  const config = getFileIcon(name, isDirectory, isOpen);
  const Icon = config.icon;

  return (
    <Icon
      size={size}
      className={[config.className, className].filter(Boolean).join(" ")}
    />
  );
}
