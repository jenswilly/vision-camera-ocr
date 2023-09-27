import type { Frame } from "react-native-vision-camera";

type BoundingFrame = {
	x: number;
	y: number;
	width: number;
	height: number;
	boundingCenterX: number;
	boundingCenterY: number;
};
type Point = { x: number; y: number };

type TextElement = {
	text: string;
	frame: BoundingFrame;
	cornerPoints: Point[];
};

type TextLine = {
	text: string;
	elements: TextElement[];
	frame: BoundingFrame;
	recognizedLanguages: string[];
	cornerPoints: Point[];
};

type TextBlock = {
	text: string;
	lines: TextLine[];
	frame: BoundingFrame;
	recognizedLanguages: string[];
	cornerPoints: Point[];
};

type Text = {
	text: string;
	blocks: TextBlock[];
	imagePath: string | null | undefined;
	// Next three are used only on Android
	width: number | undefined;
	height: number | undefined;
	rotation: number | undefined;
};

export type OCRFrame = {
	result: Text;
};

export type OCRArgs = {
	fileName: string;
};

/**
 * Scans OCR.
 */

export function scanOCR(frame: Frame, args: OCRArgs | undefined): OCRFrame {
	"worklet";
	// @ts-ignore
	return __scanOCR(frame, args);
}
