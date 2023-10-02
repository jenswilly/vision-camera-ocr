import Vision
import AVFoundation

@objc(OCRFrameProcessorPlugin)
public class OCRFrameProcessorPlugin: FrameProcessorPlugin {

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

	private func recognizeTextHandler(request: VNRequest, error: Error?) {
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

	var foundResults: [Block] = []

	@objc
	public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable: Any]?) -> Any? {
		var fileUrl: URL?

		// Only save image if args.fileName is not empty
		if let options = arguments, let filename = options["fileName"] as? String {
			guard let cvImageBuffer = CMSampleBufferGetImageBuffer(frame.buffer) else {
				print("Failed to get image buffer from sample buffer.")
				return nil
			}
			let ciImage = CIImage(cvImageBuffer: cvImageBuffer)
			fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(filename).appendingPathExtension("jpg")
			ciImage.jpgWrite(url: fileUrl!)
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
				},
				"imagePath": (fileUrl?.path ?? nil) as Any
			] as [String : Any]]
			return resultObject
		} else {
			// Pre-iOS 14: return empty
			return nil
		}
	}
}

// https://stackoverflow.com/q/59330149/1632704
extension CIImage {
	static let writeContext = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!, options: [
		// using an extended working color space allows you to retain wide gamut information, e.g., if the input is in DisplayP3
		.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!,
		.workingFormat: CIFormat.RGBAh // 16 bit color depth, needed in extended space
	])

	func jpgWrite(url: URL) {
		// write the output in the same color space as the input; fallback to sRGB if it can't be determined
		let outputColorSpace = colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
		do {
			try CIImage.writeContext.writeJPEGRepresentation(of: self, to: url, colorSpace: outputColorSpace, options: [:])
		} catch {
		}
	}
}
