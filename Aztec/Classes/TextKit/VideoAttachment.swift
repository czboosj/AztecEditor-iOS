import Foundation
import UIKit
import Gridicons

protocol VideoAttachmentDelegate: class {
    func videoAttachment(
        _ videoAttachment: VideoAttachment,
        imageForURL url: URL,
        onSuccess success: @escaping (UIImage) -> (),
        onFailure failure: @escaping () -> ()) -> UIImage
}

/// Custom text attachment.
///
open class VideoAttachment: NSTextAttachment
{
    public struct Appearance {
        public var overlayColor = UIColor(white: 0.6, alpha: 0.6)

        /// The height of the progress bar for progress indicators
        public var progressHeight = CGFloat(2.0)

        /// The color to use when drawing the backkground of the progress indicators
        ///
        public var progressBackgroundColor = UIColor.cyan

        /// The color to use when drawing progress indicators
        ///
        public var progressColor = UIColor.blue

        /// The margin apply to the images being displayed. This is to avoid that two images in a row get glued together.
        ///
        public var margin = CGFloat(10.0)
    }


    /// This property allows the global customization of appearance properties of the TextAttachment
    ///
    open static var appearance: Appearance = Appearance()

    /// Identifier used to match this attachment with a custom UIView subclass
    ///
    fileprivate(set) open var identifier: String
    
    /// Attachment video URL
    ///
    open var srcURL: URL?


    /// Video poster image to show, while the video is not played.
    ///
    open var posterURL: URL?

    fileprivate var lastRequestedURL: URL?

    /// A progress value that indicates the progress of an attachment. It can be set between values 0 and 1
    ///
    open var progress: Double? = nil {
        willSet {
            assert(newValue == nil || (newValue! >= 0 && newValue! <= 1), "Progress must be value between 0 and 1 or nil")
            if newValue != progress {
                glyphImage = nil
            }
        }
    }

    /// The color to use when drawing the background overlay for messages, icons, and progress
    ///
    open var overlayColor: UIColor = TextAttachment.appearance.overlayColor

    /// The height of the progress bar for progress indicators
    open var progressHeight: CGFloat = TextAttachment.appearance.progressHeight

    /// The color to use when drawing the backkground of the progress indicators
    ///
    open var progressBackgroundColor: UIColor = TextAttachment.appearance.progressBackgroundColor

    /// The color to use when drawing progress indicators
    ///
    open var progressColor: UIColor = TextAttachment.appearance.progressColor

    /// The margin apply to the images being displayed. This is to avoid that two images in a row get glued together.
    ///
    open var margin: CGFloat = VideoAttachment.appearance.margin

    /// A message to display overlaid on top of the image
    ///
    open var message: NSAttributedString? {
        willSet {
            if newValue != message {
                glyphImage = nil
            }
        }
    }

    /// An image to display overlaid on top of the image has an action icon.
    ///
    open var overlayImage: UIImage? {
        willSet {
            if newValue != overlayImage {
                glyphImage = nil
            }
        }
    }


    /// Clears all overlay information that is applied to the attachment
    ///
    open func clearAllOverlays() {
        progress = nil
        message = nil
        overlayImage = nil
    }

    fileprivate var glyphImage: UIImage?

    weak var delegate: VideoAttachmentDelegate?
    
    var isFetchingImage: Bool = false

    /// Creates a new attachment
    ///
    /// - parameter identifier: An unique identifier for the attachment
    ///
    required public init(identifier: String, srcURL: URL? = nil, posterURL: URL? = nil) {
        self.identifier = identifier
        self.srcURL = srcURL
        self.posterURL = posterURL
        
        super.init(data: nil, ofType: nil)

        self.overlayImage = Gridicon.iconOfType(.video)
    }

    /// Required Initializer
    ///
    required public init?(coder aDecoder: NSCoder) {
        identifier = ""
        super.init(coder: aDecoder)

        if let decodedIndentifier = aDecoder.decodeObject(forKey: EncodeKeys.identifier.rawValue) as? String {
            identifier = decodedIndentifier
        }
        if aDecoder.containsValue(forKey: EncodeKeys.srcURL.rawValue) {
            srcURL = aDecoder.decodeObject(forKey: EncodeKeys.srcURL.rawValue) as? URL
        }

        if aDecoder.containsValue(forKey: EncodeKeys.posterURL.rawValue) {
            posterURL = aDecoder.decodeObject(forKey: EncodeKeys.posterURL.rawValue) as? URL
        }
    }

    override init(data contentData: Data?, ofType uti: String?) {
        identifier = ""
        srcURL = nil
        posterURL = nil
        super.init(data: contentData, ofType: uti)
    }

    fileprivate func setupDefaultAppearance() {
        progressHeight = VideoAttachment.appearance.progressHeight
        progressBackgroundColor = VideoAttachment.appearance.progressBackgroundColor
        progressColor = VideoAttachment.appearance.progressColor
        overlayColor = VideoAttachment.appearance.overlayColor
    }

    override open func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(identifier, forKey: EncodeKeys.identifier.rawValue)
        if let url = self.srcURL {
            aCoder.encode(url, forKey: EncodeKeys.srcURL.rawValue)
        }
        if let url = self.posterURL {
            aCoder.encode(url, forKey: EncodeKeys.posterURL.rawValue)
        }
    }

    fileprivate enum EncodeKeys: String {
        case identifier
        case srcURL
        case posterURL
    }
    // MARK: - Origin calculation

    fileprivate func xPosition(forContainerWidth containerWidth: CGFloat) -> CGFloat {
        let imageWidth = onScreenWidth(containerWidth)

        return CGFloat(floor((containerWidth - imageWidth) / 2))
    }

    fileprivate func onScreenHeight(_ containerWidth: CGFloat) -> CGFloat {
        if let image = image {
            let targetWidth = onScreenWidth(containerWidth)
            let scale = targetWidth / image.size.width

            return floor(image.size.height * scale) + (margin * 2)
        } else {
            return 0
        }
    }

    fileprivate func onScreenWidth(_ containerWidth: CGFloat) -> CGFloat {
        if let image = image {
            return floor(min(image.size.width, containerWidth))
        } else {
            return 0
        }
    }

    // MARK: - NSTextAttachmentContainer

    override open func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        
        updateImage(inTextContainer: textContainer)

        guard let image = image else {
            return nil
        }

        if let cachedImage = glyphImage, imageBounds.size.equalTo(cachedImage.size) {
            return cachedImage
        }

        glyphImage = glyph(basedOnImage:image, forBounds: imageBounds)

        return glyphImage
    }

    fileprivate func glyph(basedOnImage image:UIImage, forBounds bounds: CGRect) -> UIImage? {

        let containerWidth = bounds.size.width
        let origin = CGPoint(x: xPosition(forContainerWidth: bounds.size.width), y: margin)
        let size = CGSize(width: onScreenWidth(containerWidth), height: onScreenHeight(containerWidth) - margin)

        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0)

        image.draw(in: CGRect(origin: origin, size: size))

        drawOverlay(at:origin, size: size)
        drawProgress(at:origin, size: size)


        var imagePadding: CGFloat = 0
        if let overlayImage = overlayImage {
            UIColor.white.set()
            let center = CGPoint(x: round(origin.x + (size.width / 2.0)), y: round(origin.y + (size.height / 2.0)))
            let radius = round(overlayImage.size.width * 2.0/3.0)
            let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
            path.stroke()
            overlayImage.draw(at: CGPoint(x: round(center.x - (overlayImage.size.width / 2.0)), y: round(center.y - (overlayImage.size.height / 2.0))))
            imagePadding += radius * 2;
        }

        if let message = message {
            let textRect = message.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            var y =  origin.y + ((size.height - textRect.height) / 2.0)
            if imagePadding != 0 {
                y = origin.y + ((size.height + imagePadding) / 2.0)
            }
            let textPosition = CGPoint(x: origin.x, y: y)
            message.draw(in: CGRect(origin: textPosition , size: CGSize(width:size.width, height:textRect.size.height)))
        }

        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result;
    }

    fileprivate func drawOverlay(at origin: CGPoint, size:CGSize) {
        guard message != nil || progress != nil || overlayImage != nil else {
            return
        }
        let box = UIBezierPath()
        box.move(to: CGPoint(x:origin.x, y:origin.y))
        box.addLine(to: CGPoint(x: origin.x + size.width, y: origin.y))
        box.addLine(to: CGPoint(x: origin.x + size.width, y: origin.y + size.height))
        box.addLine(to: CGPoint(x: origin.x, y: origin.y + size.height))
        box.addLine(to: CGPoint(x: origin.x, y: origin.y))
        box.lineWidth = 2.0
        overlayColor.setFill()
        box.fill()
    }

    fileprivate func drawProgress(at origin: CGPoint, size:CGSize) {
        guard let progress = progress else {
            return
        }
        let lineY = origin.y + (progressHeight / 2.0)

        let backgroundPath = UIBezierPath()
        backgroundPath.lineWidth = progressHeight
        progressBackgroundColor.setStroke()
        backgroundPath.move(to: CGPoint(x:origin.x, y: lineY))
        backgroundPath.addLine(to: CGPoint(x: origin.x + size.width, y: lineY ))
        backgroundPath.stroke()

        let path = UIBezierPath()
        path.lineWidth = progressHeight
        progressColor.setStroke()
        path.move(to: CGPoint(x:origin.x, y: lineY))
        path.addLine(to: CGPoint(x: origin.x + (size.width * CGFloat(max(0,min(progress,1)))), y: lineY ))
        path.stroke()
    }

    /// Returns the "Onscreen Character Size" of the attachment range. When we're in Alignment.None,
    /// the attachment will be 'Inline', and thus, we'll return the actual Associated View Size.
    /// Otherwise, we'll always take the whole container's width.
    ///
    override open func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        
        updateImage(inTextContainer: textContainer)
        
        if image == nil {
            return CGRect.zero
        }

        let padding = textContainer?.lineFragmentPadding ?? 0
        let width = lineFrag.width - padding * 2

        return CGRect(origin: CGPoint.zero, size: CGSize(width: width, height: onScreenHeight(width)))
    }

    func updateImage(inTextContainer textContainer: NSTextContainer? = nil) {

        guard let delegate = delegate else {
            assertionFailure("This class doesn't really support not having an updater set.")
            return
        }
        
        guard let url = posterURL, !isFetchingImage && url != lastRequestedURL else {
            return
        }
        
        isFetchingImage = true
        
        let image = delegate.videoAttachment(self, imageForURL: url, onSuccess: { [weak self] image in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.lastRequestedURL = url
                strongSelf.isFetchingImage = false
                strongSelf.image = image
                strongSelf.invalidateLayout(inTextContainer: textContainer)
            }, onFailure: { [weak self] _ in
                
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.isFetchingImage = false
                strongSelf.invalidateLayout(inTextContainer: textContainer)
            })

        if self.image == nil {
            self.image = image
        }
    }
    
    fileprivate func invalidateLayout(inTextContainer textContainer: NSTextContainer?) {
        textContainer?.layoutManager?.invalidateLayoutForAttachment(self)
    }
}
