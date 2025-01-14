//
//  SubredditHeaderView.swift
//  Slide for Reddit
//
//  Created by Carlos Crane on 1/11/17.
//  Copyright © 2017 Haptic Apps. All rights reserved.
//

import Alamofire
import Anchorage
import AudioToolbox
import reddift
import RLBAlertsPickers
import SDCAlertView
import SwiftyJSON
import UIKit

class SubredditHeaderView: UIView {

    var subscribers: UILabel = UILabel()
    var here: UILabel = UILabel()
    var info: TextDisplayStackView!
    
    var submit = UITableViewCell()
    var sorting = UITableViewCell()
    var mods = UITableViewCell()
    var flair = UITableViewCell()

    @objc func mods(_ sender: UITableViewCell) {
        var list: [User] = []
        do {
            try (UIApplication.shared.delegate as! AppDelegate).session?.about(subreddit!, aboutWhere: SubredditAbout.moderators, completion: { (result) in
                switch result {
                case .failure:
                    DispatchQueue.main.async {
                        BannerUtil.makeBanner(text: "No subreddit moderators found!", color: GMColor.red500Color(), seconds: 3, context: self.parentController)
                    }
                case .success(let users):
                    list.append(contentsOf: users)
                    DispatchQueue.main.async {
                        let sheet = DragDownAlertMenu(title: "Moderators", subtitle: "\(self.subreddit!.displayName.getSubredditFormatted())", icon: nil, themeColor: ColorUtil.accentColorForSub(sub: self.subreddit!.displayName), full: false)

                        sheet.addAction(title: "Message \(self.subreddit!.displayName.getSubredditFormatted()) moderators", icon: UIImage(sfString: SFSymbol.shieldLefthalfFill, overrideString: "mod")?.menuIcon(), action: {
                            VCPresenter.openRedditLink("https://www.reddit.com/message/compose?to=/r/\(self.subreddit!.displayName)", self.parentController?.navigationController, self.parentController)
                        })

                        for user in users {
                            sheet.addAction(title: "u/\(user.name)", icon: nil, action: {
                                VCPresenter.showVC(viewController: ProfileViewController.init(name: user.name), popupIfPossible: false, parentNavigationController: self.parentController?.navigationController, parentViewController: self.parentController)
                            })
                           // TODO: - maybe tags or colors?
                        }
                        
                        sheet.show(self.parentController)
                    }
                }
            })
        } catch {
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        let pointForTargetViewmore: CGPoint = mods.convert(point, from: self)
        if mods.bounds.contains(pointForTargetViewmore) {
            return mods
        }

        let pointForTargetViewsort: CGPoint = sorting.convert(point, from: self)
        if sorting.bounds.contains(pointForTargetViewsort) {
            return sorting
        }

        let pointForTargetViewsubmit: CGPoint = submit.convert(point, from: self)
        if submit.bounds.contains(pointForTargetViewsubmit) {
            return submit
        }

        return super.hitTest(point, with: event)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.submit.textLabel?.text = "New post"
        self.submit.accessoryType = .none
        self.submit.backgroundColor = UIColor.foregroundColor
        self.submit.textLabel?.textColor = UIColor.fontColor
        self.submit.imageView?.image = UIImage(sfString: SFSymbol.pencil, overrideString: "edit")?.menuIcon()
        self.submit.imageView?.tintColor = UIColor.fontColor
        self.submit.layer.cornerRadius = 5
        self.submit.clipsToBounds = true

        self.sorting.textLabel?.text = "Default subreddit sorting"
        self.sorting.accessoryType = .none
        self.sorting.backgroundColor = UIColor.foregroundColor
        self.sorting.textLabel?.textColor = UIColor.fontColor
        self.sorting.imageView?.image = UIImage(sfString: SFSymbol.arrowUpArrowDownCircle, overrideString: "ic_sort_white")?.menuIcon()
        self.sorting.imageView?.tintColor = UIColor.fontColor
        self.sorting.layer.cornerRadius = 5
        self.sorting.clipsToBounds = true

        self.mods.textLabel?.text = "Subreddit moderators"
        self.mods.accessoryType = .none
        self.mods.backgroundColor = UIColor.foregroundColor
        self.mods.textLabel?.textColor = UIColor.fontColor
        self.mods.imageView?.image = UIImage(sfString: SFSymbol.shieldLefthalfFill, overrideString: "mod")?.menuIcon()
        self.mods.imageView?.tintColor = UIColor.fontColor
        self.mods.layer.cornerRadius = 5
        self.mods.clipsToBounds = true

        self.flair.accessoryType = .none
        self.flair.backgroundColor = UIColor.foregroundColor
        self.flair.textLabel?.textColor = UIColor.fontColor
        self.flair.imageView?.image = UIImage(sfString: SFSymbol.flagFill, overrideString: "flag")?.menuIcon()
        self.flair.imageView?.tintColor = UIColor.fontColor
        self.flair.layer.cornerRadius = 5
        self.flair.clipsToBounds = true

        self.info = TextDisplayStackView.init(fontSize: 16, submission: false, color: .blue, width: self.frame.size.width - 24, delegate: self)
        self.info.isUserInteractionEnabled = true
        
        self.subscribers = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        subscribers.numberOfLines = 1
        subscribers.font = UIFont.systemFont(ofSize: 16)
        subscribers.textColor = UIColor.white

        self.here = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        here.numberOfLines = 1
        here.font = UIFont.systemFont(ofSize: 16)
        here.textColor = UIColor.white

        if AccountController.isLoggedIn {
            addSubviews(submit, info, subscribers, here, sorting, mods, flair)
        } else {
            addSubviews(submit, info, subscribers, here, sorting, mods)
        }
        
        self.clipsToBounds = true
        
        setupAnchors()

        let pTap = UITapGestureRecognizer(target: self, action: #selector(self.mods(_:)))
        mods.addGestureRecognizer(pTap)
        mods.isUserInteractionEnabled = true

        let sTap = UITapGestureRecognizer(target: self, action: #selector(self.sort(_:)))
        sorting.addGestureRecognizer(sTap)
        sorting.isUserInteractionEnabled = true

        let nTap = UITapGestureRecognizer(target: self, action: #selector(self.new(_:)))
        submit.addGestureRecognizer(nTap)
        submit.isUserInteractionEnabled = true
        
        let fTap = UITapGestureRecognizer(target: self, action: #selector(self.flair(_:)))
        flair.addGestureRecognizer(fTap)
        flair.isUserInteractionEnabled = true
        
    }
    
    @objc func new(_ selector: UITableViewCell) {
        PostActions.showPostMenu(parentController!, sub: self.subreddit!.displayName)
    }
    
    @objc func flair(_ selector: UITableViewCell) {
        if let subName = subreddit?.displayName, let token = (UIApplication.shared.delegate as? AppDelegate)?.session?.token {
            let requestString = "https://www.reddit.com/r/\(subName)/api/user_flair_v2.json"
            AF.request(requestString, method: .get, headers: ["Authorization": "bearer \(token.accessToken)"]).responseString { [weak self] response in
                guard let self = self else { return }
                do {
                    guard let data = response.data else {
                        return
                    }
                    let json = try JSON(data: data)
                    if let flairs = json.array {
                        let alert = DragDownAlertMenu(title: "Available flairs", subtitle: "\(self.subreddit!.displayName.getSubredditFormatted())", icon: nil)
                        
                        for item in flairs {
                            if let richtext = item["richtext"].array?[0] {
                                let image = richtext["u"].stringValue
                                let text = richtext["t"].stringValue
                                let iconText = richtext["a"].stringValue
                                let title = item["text"].stringValue
                                let editable = item["text_editable"].boolValue
                                let id = item["id"].stringValue

                                if !image.isEmpty {
                                    alert.addView(title: title, icon_url: image) { [weak self] in
                                        guard let self = self else { return }
                                        alert.dismiss(animated: true) {
                                            if editable {
                                                self.editFlair(flairID: id, flairText: iconText, subName: subName, icon: image)
                                            } else {
                                                self.submitFlairChange(id, subName: subName)
                                            }
                                        }
                                    }
                                } else {
                                    alert.addAction(title: title, icon: nil) { [weak self] in
                                        guard let self = self else { return }
                                        alert.dismiss(animated: true) {
                                            if editable {
                                                self.editFlair(flairID: id, flairText: text, subName: subName, icon: image)
                                            } else {
                                                self.submitFlairChange(id, subName: subName)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        alert.show(self.parentController)
                    }
                } catch {
                }
            }
        }
    }
    
    var flairText: String?
    
    func editFlair(flairID: String, flairText: String, subName: String, icon: String?) {
        let alert = DragDownAlertMenu(title: "Edit flair text", subtitle: "", icon: icon)
        
        alert.addTextInput(title: "Set flair", icon: UIImage(sfString: SFSymbol.flagFill, overrideString: "save-1")?.menuIcon(), action: {
            alert.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.submitFlairChange(flairID, subName: subName, text: alert.getText() ?? flairText)
            }
        }, inputPlaceholder: "Flair text...", inputValue: flairText, inputIcon: UIImage(sfString: SFSymbol.flagFill, overrideString: "flag")!.menuIcon(), textRequired: true, exitOnAction: true)
        
        alert.show(parentController)
    }
    
    func submitFlairChange(_ flairID: String, subName: String, text: String? = "") {
        do {
            try (UIApplication.shared.delegate as! AppDelegate).session?.flairUser(subName, flairId: flairID, username: AccountController.currentName, text: text ?? "") { result in
                switch result {
                case .failure(let error):
                    print(error)
                    DispatchQueue.main.async {
                        BannerUtil.makeBanner(text: "Flair not set", color: GMColor.red500Color(), seconds: 3, context: self.parentController)
                    }
                case .success(let success):
                    print(success)
                    DispatchQueue.main.async {
                        BannerUtil.makeBanner(text: "Flair set successfully!", seconds: 3, context: self.parentController)
                        // TODO update flair view on sidebar
                    }
                }}
        } catch {
        }
    }

    @objc func sort(_ selector: UITableViewCell) {
        let actionSheetController = DragDownAlertMenu(title: "Default sorting for \(self.subreddit!.displayName.getSubredditFormatted())", subtitle: "Overrides the default in Settings > General", icon: nil, themeColor: ColorUtil.accentColorForSub(sub: self.subreddit!.displayName), full: true)

        let selected = UIImage(sfString: SFSymbol.checkmarkCircle, overrideString: "selected")!.menuIcon()

        for link in LinkSortType.cases {
            actionSheetController.addAction(title: link.description, icon: SettingValues.getLinkSorting(forSubreddit: self.subreddit!.displayName) == link ? selected : nil) {
                self.showTimeMenu(s: link, selector: selector)
            }
        }

        actionSheetController.show(self.parentController)
    }

    func showTimeMenu(s: LinkSortType, selector: UITableViewCell) {
        if s == .hot || s == .new || s == .rising || s == .best {
            UserDefaults.standard.set(s.path, forKey: self.subreddit!.displayName.lowercased() + "Sorting")
            UserDefaults.standard.set(TimeFilterWithin.day.param, forKey: self.subreddit!.displayName.lowercased() + "Time")
            UserDefaults.standard.synchronize()
            return
        } else {
            let actionSheetController = DragDownAlertMenu(title: "Select a time period", subtitle: "", icon: nil, themeColor: ColorUtil.accentColorForSub(sub: self.subreddit!.displayName), full: true)

            let selected = UIImage(sfString: SFSymbol.checkmarkCircle, overrideString: "selected")!.getCopy(withSize: .square(size: 20), withColor: .blue)

            for t in TimeFilterWithin.cases {
                actionSheetController.addAction(title: t.param, icon: SettingValues.getTimePeriod(forSubreddit: self.subreddit!.displayName) == t ? selected : nil) {
                    UserDefaults.standard.set(s.path, forKey: self.subreddit!.displayName.lowercased() + "Sorting")
                    UserDefaults.standard.set(t.param, forKey: self.subreddit!.displayName.lowercased() + "Time")
                    UserDefaults.standard.synchronize()
                }
            }

            actionSheetController.show(self.parentController)
        }
    }

    func exit() {
        parentController?.dismiss(animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func subscribe(_ sender: AnyObject) {
    }

    @objc func theme(_ sender: AnyObject) {

    }

    @objc func submit(_ sender: AnyObject) {

    }

    var content: NSAttributedString?
    var textHeight: CGFloat = 0
    var descHeight: CGFloat = 0
    weak var parentController: (UIViewController & MediaVCDelegate)?

    func setSubreddit(subreddit: Subreddit, parent: MediaViewController, _ width: CGFloat) {
        self.subreddit = subreddit
        self.setWidth = width
        self.parentController = parent
        
        here.numberOfLines = 0
        subscribers.numberOfLines = 0
        subscribers.font = FontGenerator.boldFontOfSize(size: 14, submission: true)
        here.font = subscribers.font
        here.textAlignment = .center
        subscribers.textAlignment = .center
        here.textColor = UIColor.fontColor
        subscribers.textColor = UIColor.fontColor

        let attrs = [NSAttributedString.Key.font: FontGenerator.boldFontOfSize(size: 20, submission: true)]
        var attributedString = NSMutableAttributedString(string: "\(subreddit.subscribers.delimiter)", attributes: attrs)
        var subt = NSMutableAttributedString(string: "\nSUBSCRIBERS")
        attributedString.append(subt)
        subscribers.attributedText = attributedString
        
        attributedString = NSMutableAttributedString(string: "\(subreddit.accountsActive.delimiter)", attributes: attrs)
        subt = NSMutableAttributedString(string: "\nHERE")
        attributedString.append(subt)
        here.attributedText = attributedString

        let width = UIScreen.main.bounds.width

        info.estimatedWidth = width - 24
        if !subreddit.descriptionHtml.isEmpty() {
            info.tColor = ColorUtil.accentColorForSub(sub: subreddit.displayName)
            info.setTextWithTitleHTML(NSMutableAttributedString(), htmlString: subreddit.descriptionHtml)
            descHeight = info.estimatedHeight
        }
        
        self.flair.textLabel?.text = "Your flair on \(subreddit.displayName.getSubredditFormatted())"
    }

    var subreddit: Subreddit?
    var setWidth: CGFloat = 0

    func setupAnchors() {
    
        self.widthAnchor /==/ UIScreen.main.bounds.width

        submit.horizontalAnchors /==/ horizontalAnchors + CGFloat(12)
        sorting.horizontalAnchors /==/ horizontalAnchors + CGFloat(12)
        mods.horizontalAnchors /==/ horizontalAnchors + CGFloat(12)
        if AccountController.isLoggedIn {
            flair.horizontalAnchors /==/ horizontalAnchors + CGFloat(12)
        }
        info.horizontalAnchors /==/ horizontalAnchors + CGFloat(12)
        subscribers.leftAnchor /==/ leftAnchor + CGFloat(12)
        subscribers.rightAnchor /==/ here.leftAnchor - CGFloat(4)
        here.leftAnchor /==/ subscribers.rightAnchor + CGFloat(4)
        here.widthAnchor /==/ subscribers.widthAnchor
        here.rightAnchor /==/ rightAnchor - CGFloat(12)
        here.centerYAnchor /==/ subscribers.centerYAnchor
        
        subscribers.topAnchor /==/ topAnchor + CGFloat(16)
        submit.topAnchor /==/ subscribers.bottomAnchor + CGFloat(8)
        mods.topAnchor /==/ submit.bottomAnchor + CGFloat(2)
        sorting.topAnchor /==/ mods.bottomAnchor + CGFloat(2)
        if AccountController.isLoggedIn {
            flair.heightAnchor /==/ CGFloat(50)
            flair.topAnchor /==/ sorting.bottomAnchor + CGFloat(2)
            info.topAnchor /==/ flair.bottomAnchor + CGFloat(16)
        } else {
            info.topAnchor /==/ sorting.bottomAnchor + CGFloat(16)
        }
        info.bottomAnchor /==/ bottomAnchor - CGFloat(16)
        subscribers.heightAnchor /==/ CGFloat(50)
        submit.heightAnchor /==/ CGFloat(50)
        mods.heightAnchor /==/ CGFloat(50)
        sorting.heightAnchor /==/ CGFloat(50)
    }

    func getEstHeight() -> CGFloat {
        return CGFloat(340) + (descHeight)
    }
}

extension SubredditHeaderView: TextDisplayStackViewDelegate {
    func linkTapped(url: URL, text: String) {
        if !text.isEmpty {
            self.parentController?.showSpoiler(text)
        } else {
            self.parentController?.doShow(url: url, heroView: nil, finalSize: nil, heroVC: nil, link: SubmissionObject())
        }
    }
    
    func linkLongTapped(url: URL) {
        
        let alertController = DragDownAlertMenu(title: "Link options", subtitle: url.absoluteString, icon: url.absoluteString)
        
        alertController.addAction(title: "Share URL", icon: UIImage(sfString: SFSymbol.squareAndArrowUp, overrideString: "share")!.menuIcon()) {
            let shareItems: Array = [url]
            let activityViewController: UIActivityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self
            self.parentController?.present(activityViewController, animated: true, completion: nil)
        }
        
        alertController.addAction(title: "Copy URL", icon: UIImage(sfString: SFSymbol.docOnDocFill, overrideString: "copy")!.menuIcon()) {
            UIPasteboard.general.setValue(url, forPasteboardType: "public.url")
            BannerUtil.makeBanner(text: "URL Copied", seconds: 5, context: self.parentController)
        }
        
        alertController.addAction(title: "Open in default app", icon: UIImage(sfString: SFSymbol.safariFill, overrideString: "nav")!.menuIcon()) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }
        }
        
        let open = OpenInChromeController.init()
        if open.isChromeInstalled() {
            alertController.addAction(title: "Open in Chrome", icon: UIImage(named: "world")!.menuIcon()) {
                open.openInChrome(url, callbackURL: nil, createNewTab: true)
            }
        }
        
        if #available(iOS 10.0, *) {
            HapticUtility.hapticActionStrong()
        } else if SettingValues.hapticFeedback {
            AudioServicesPlaySystemSound(1519)
        }
        
        if parentController != nil {
            alertController.show(parentController!)
        }
    }
    
    func previewProfile(profile: String) {
        // unused
    }
}

extension UIImage {

    func addImagePadding(x: CGFloat, y: CGFloat) -> UIImage {
        let width: CGFloat = self.size.width + x
        let height: CGFloat = self.size.width + y
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        let context: CGContext = UIGraphicsGetCurrentContext()!
        UIGraphicsPushContext(context)
        let origin: CGPoint = CGPoint(x: (width - self.size.width) / 2, y: (height - self.size.height) / 2)
        self.draw(at: origin)
        UIGraphicsPopContext()
        let imageWithPadding = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return imageWithPadding!
    }
}

//https://medium.com/@sdrzn/adding-gesture-recognizers-with-closures-instead-of-selectors-9fb3e09a8f0b
extension UIView {

    // In order to create computed properties for extensions, we need a key to
    // store and access the stored property
    private struct AssociatedObjectKeys {
        static var tapGestureRecognizer = "tapGR"
        static var longTapGestureRecognizer = "longTapGR"
        static var longTapGestureRecognizerInstance = "longTapGRInstance"
        static var longTapGestureTimer = "longTapTimer"
        static var longTapGestureCancelled = "longTapCancelled"
    }

    private typealias Action = ((_ sender: UIGestureRecognizer) -> Void)?

    // Set our computed property type to a closure
    private var tapGestureRecognizerAction: Action? {
        get {
            let tapGestureRecognizerActionInstance = objc_getAssociatedObject(self, &AssociatedObjectKeys.tapGestureRecognizer) as? Action
            return tapGestureRecognizerActionInstance
        }
        set {
            if let newValue = newValue {
                // Computed properties get stored as associated objects
                objc_setAssociatedObject(self, &AssociatedObjectKeys.tapGestureRecognizer, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    private var longTapGestureRecognizerAction: Action? {
        get {
            let tapGestureRecognizerActionInstance = objc_getAssociatedObject(self, &AssociatedObjectKeys.longTapGestureRecognizer) as? Action
            return tapGestureRecognizerActionInstance
        }
        set {
            if let newValue = newValue {
                // Computed properties get stored as associated objects
                objc_setAssociatedObject(self, &AssociatedObjectKeys.longTapGestureRecognizer, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
    }
    
    private var longTapGestureRecognizer: UIGestureRecognizer? {
        get {
            let tapGestureRecognizerActionInstance = objc_getAssociatedObject(self, &AssociatedObjectKeys.longTapGestureRecognizerInstance) as? UIGestureRecognizer
            return tapGestureRecognizerActionInstance
        }
        set {
            if let newValue = newValue {
                // Computed properties get stored as associated objects
                objc_setAssociatedObject(self, &AssociatedObjectKeys.longTapGestureRecognizerInstance, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    private var timer: Timer? {
        get {
            let tapGestureRecognizerActionInstance = objc_getAssociatedObject(self, &AssociatedObjectKeys.longTapGestureTimer) as? Timer
            return tapGestureRecognizerActionInstance
        }
        set {
            if let newValue = newValue {
                // Computed properties get stored as associated objects
                objc_setAssociatedObject(self, &AssociatedObjectKeys.longTapGestureTimer, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    private var cancelled: Bool? {
        get {
            let tapGestureRecognizerActionInstance = objc_getAssociatedObject(self, &AssociatedObjectKeys.longTapGestureCancelled) as? Bool
            return tapGestureRecognizerActionInstance
        }
        set {
            if let newValue = newValue {
                // Computed properties get stored as associated objects
                objc_setAssociatedObject(self, &AssociatedObjectKeys.longTapGestureCancelled, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    // This is the meat of the sauce, here we create the tap gesture recognizer and
    // store the closure the user passed to us in the associated object we declared above
    public func addTapGestureRecognizer(action: ((_ sender: UIGestureRecognizer) -> Void)?) {
        self.isUserInteractionEnabled = true
        self.tapGestureRecognizerAction = action
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        self.addGestureRecognizer(tapGestureRecognizer)
    }
    
    public func addTapGestureRecognizer(delegate: UIGestureRecognizerDelegate, action: ((_ sender: UIGestureRecognizer) -> Void)?) {
        self.isUserInteractionEnabled = true
        self.tapGestureRecognizerAction = action
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        self.addGestureRecognizer(tapGestureRecognizer)
    }

    public func addLongTapGestureRecognizer(action: ((_ sender: UIGestureRecognizer) -> Void)?) {
        self.isUserInteractionEnabled = true
        self.longTapGestureRecognizerAction = action
        let tapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTapGesture))
        tapGestureRecognizer.minimumPressDuration = 0.36
        self.longTapGestureRecognizer = tapGestureRecognizer
        self.addGestureRecognizer(tapGestureRecognizer)
    }
    
    public func addLongTapGestureRecognizerReturn(action: ((_ sender: UIGestureRecognizer) -> Void)?) -> UILongPressGestureRecognizer {
        self.isUserInteractionEnabled = true
        self.longTapGestureRecognizerAction = action
        let tapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTapGesture))
        tapGestureRecognizer.minimumPressDuration = 0.36
        self.addGestureRecognizer(tapGestureRecognizer)
        return tapGestureRecognizer
    }
    
    public func addLongTapGestureRecognizer(delegate: UIGestureRecognizerDelegate, action: ((_ sender: UIGestureRecognizer) -> Void)?) {
        self.isUserInteractionEnabled = true
        self.longTapGestureRecognizerAction = action
        let tapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTapGesture))
        tapGestureRecognizer.minimumPressDuration = 0.36
        self.longTapGestureRecognizer = tapGestureRecognizer
        self.addGestureRecognizer(tapGestureRecognizer)
    }

    // Every time the user taps on the UIImageView, this function gets called,
    // which triggers the closure we stored
    @objc private func handleTapGesture(sender: UITapGestureRecognizer) {
        if let action = self.tapGestureRecognizerAction {
            action?(sender)
        }
    }
    
    @objc private func doLongGesture() {
        timer?.invalidate()
        if cancelled ?? false {
            return
        }
        if let action = self.longTapGestureRecognizerAction {
            if #available(iOS 10.0, *) {
                HapticUtility.hapticActionStrong()
            } else if SettingValues.hapticFeedback {
                AudioServicesPlaySystemSound(1519)
            }

            if let long = self.longTapGestureRecognizer {
                action?(long)
            }
        }
    }

    @objc private func handleLongTapGesture(sender: UITapGestureRecognizer) {
        if sender.state == UIGestureRecognizer.State.began {
            if sender.state == UIGestureRecognizer.State.began {
                cancelled = false
                timer = Timer.scheduledTimer(timeInterval: 0.36,
                                             target: self,
                                             selector: #selector(self.doLongGesture),
                                             userInfo: nil,
                                             repeats: false)
                
            }
            if sender.state == UIGestureRecognizer.State.ended {
                timer?.invalidate()
                cancelled? = true
            }
        }
    }
}

extension Int {
    private static var numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        
        return numberFormatter
    }()
    
    var delimiter: String {
        return Int.numberFormatter.string(from: NSNumber(value: self)) ?? ""
    }
}
