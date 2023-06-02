import Vision
import AVFoundation

@objc(OCRFrameProcessorPlugin)
public class OCRFrameProcessorPlugin: NSObject, FrameProcessorPluginBase {

	struct BlockFrame: Encodable {
		let x: CGFloat
		let y: CGFloat
		let width: CGFloat
		let height: CGFloat
		let boundingCenterX: CGFloat
		let boundingCenterY: CGFloat
	}

	struct Block: Encodable {
		let text: String
		let frame: BlockFrame
	}

	struct Result: Encodable {
		let text: String
		let blocks: [Block]
	}

	/*
	 private static var textRecognizer = TextRecognizer.textRecognizer()

	 private static func getBlockArray(_ blocks: [TextBlock]) -> [[String: Any]] {

	 var blockArray: [[String: Any]] = []

	 for block in blocks {
	 blockArray.append([
	 "text": block.text,
	 "recognizedLanguages": getRecognizedLanguages(block.recognizedLanguages),
	 "cornerPoints": getCornerPoints(block.cornerPoints),
	 "frame": getFrame(block.frame),
	 "lines": getLineArray(block.lines),
	 ])
	 }

	 return blockArray
	 }

	 private static func getLineArray(_ lines: [TextLine]) -> [[String: Any]] {

	 var lineArray: [[String: Any]] = []

	 for line in lines {
	 lineArray.append([
	 "text": line.text,
	 "recognizedLanguages": getRecognizedLanguages(line.recognizedLanguages),
	 "cornerPoints": getCornerPoints(line.cornerPoints),
	 "frame": getFrame(line.frame),
	 "elements": getElementArray(line.elements),
	 ])
	 }

	 return lineArray
	 }

	 private static func getElementArray(_ elements: [TextElement]) -> [[String: Any]] {

	 var elementArray: [[String: Any]] = []

	 for element in elements {
	 elementArray.append([
	 "text": element.text,
	 "cornerPoints": getCornerPoints(element.cornerPoints),
	 "frame": getFrame(element.frame),
	 ])
	 }

	 return elementArray
	 }

	 private static func getRecognizedLanguages(_ languages: [TextRecognizedLanguage]) -> [String] {

	 var languageArray: [String] = []

	 for language in languages {
	 guard let code = language.languageCode else {
	 print("No language code exists")
	 break;
	 }
	 languageArray.append(code)
	 }

	 return languageArray
	 }

	 private static func getCornerPoints(_ cornerPoints: [NSValue]) -> [[String: CGFloat]] {

	 var cornerPointArray: [[String: CGFloat]] = []

	 for cornerPoint in cornerPoints {
	 guard let point = cornerPoint as? CGPoint else {
	 print("Failed to convert corner point to CGPoint")
	 break;
	 }
	 cornerPointArray.append([ "x": point.x, "y": point.y])
	 }

	 return cornerPointArray
	 }

	 private static func getFrame(_ frameRect: CGRect) -> [String: CGFloat] {

	 let offsetX = (frameRect.midX - ceil(frameRect.width)) / 2.0
	 let offsetY = (frameRect.midY - ceil(frameRect.height)) / 2.0

	 let x = frameRect.maxX + offsetX
	 let y = frameRect.minY + offsetY

	 return [
	 "x": frameRect.midX + (frameRect.midX - x),
	 "y": frameRect.midY + (y - frameRect.midY),
	 "width": frameRect.width,
	 "height": frameRect.height,
	 "boundingCenterX": frameRect.midX,
	 "boundingCenterY": frameRect.midY
	 ]
	 }
	 */

	private static let jsonEncoder = JSONEncoder()

	private static func recognizeTextHandler(request: VNRequest, error: Error?) {
		if #available(iOS 14.0, *) {
			guard let observations = request.results as? [VNRecognizedTextObservation] else {
				return
			}

			let recognitions: [Block] = observations.compactMap { observation in
				// Find the top observation.
				guard let candidate = observation.topCandidates(1).first else { return nil }

				// Raw rect
				// Find the bounding-box observation for the string range.
				let stringRange = candidate.string.startIndex..<candidate.string.endIndex
				guard let box = try? candidate.boundingBox(for: stringRange) else { return nil }

				// Get the normalized CGRect value.
				let frame = BlockFrame(x: box.topLeft.x, y: box.topLeft.y, width: box.boundingBox.width, height: box.boundingBox.height, boundingCenterX: box.boundingBox.midX, boundingCenterY: box.boundingBox.midY)

				return Block(text: candidate.string, frame: frame)
			}

			// Add to external array
			foundResults.append(contentsOf: recognitions)
		} else {
			// Fallback on earlier versions
		}
	}

	static var foundResults: [Block] = []

	@objc
	public static func callback(_ frame: Frame!, withArgs _: [Any]!) -> Any! {

		guard (CMSampleBufferGetImageBuffer(frame.buffer) != nil) else {
			print("Failed to get image buffer from sample buffer.")
			return nil
		}

		if #available(iOS 14.0, *) {
			// Create a new image-request handler.
			let requestHandler = VNImageRequestHandler(cmSampleBuffer: frame.buffer)

			// Create a new request to recognize text.
			let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
			request.recognitionLevel = .accurate

			do {
				// Perform the text-recognition request.
				foundResults = []
				try requestHandler.perform([request])
			} catch {
				print("Unable to perform the requests: \(error).")
				return nil
			}

			let resultObject = ["result": [
				"text": foundResults.map { $0.text }.joined(separator: " "),
				"blocks": foundResults.map { block in
					[
						"text": block.text,
						"frame": [
							"x": block.frame.x,
							"y": 1 - block.frame.y,		// Flip Y-axis to match top-left → bottom-right coordinate system
							"width": block.frame.width,
							"height": block.frame.height,
							"boundingCenterX": block.frame.boundingCenterX,
							"boundingCenterY": block.frame.boundingCenterY,
						]
					] as [String : Any]
				}
			] as [String : Any]]
			return resultObject
		} else {
			// Pre-iOS 14: return empty
			return nil
		}
	}
}

