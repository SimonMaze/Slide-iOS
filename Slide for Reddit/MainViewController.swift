//
//  MainViewController.swift
//  Slide for Reddit
//
//  Created by Carlos Crane on 7/19/20.
//  Copyright © 2020 Haptic Apps. All rights reserved.
//

import Anchorage
import AudioToolbox
import BadgeSwift
import reddift
import SDCAlertView
import StoreKit
import UIKit
import WatchConnectivity
#if canImport(WidgetKit)
import WidgetKit
#endif

class MainViewController: ColorMuxPagingViewController, UINavigationControllerDelegate, ReadLaterDelegate {

    // MARK: - Variables
    /*
    Corresponds to USR_DOMAIN in info.plist, which derives its value
    from USR_DOMAIN in the pbxproj build settings. Default is `ccrama.me`.
    */
    func USR_DOMAIN() -> String {
       return Bundle.main.object(forInfoDictionaryKey: "USR_DOMAIN") as! String
    }

    var isReload = false
    var readLaterBadge: BadgeSwift?
    public static var current: String = ""
    public var toolbar: UIView?
    var tabBar: SubredditPagingTitleCollectionView!
    var subs: UIView?
    var selected = false

    var finalSubs = [String]()

    var checkedClipboardOnce = false

    var more = UIButton()
    var menu = UIButton()
    var readLaterB = UIBarButtonItem()
    var sortB = UIBarButtonItem().then {
        $0.accessibilityLabel = "Change Post Sorting Order"
    }
    var sortButton: UIButton = UIButton()
    var inHeadView = UIView()

    var readLater = UIButton().then {
        $0.accessibilityLabel = "Open Read Later List"
    }
    var accountB = UIBarButtonItem()
    public static var first = true
    public var hasAppeared = false

    override var childForStatusBarHidden: UIViewController? {
        if hasAppeared && finalSubs.count > currentIndex {
            if navigationController?.topViewController != self {
                return navigationController?.topViewController
            } else {
                return viewControllers?.first(where: {
                    ($0 as? SingleSubredditViewController)?.sub == finalSubs[currentIndex]
                })
            }
        }
        return nil
    }
    
    var statusbarHeight: CGFloat {
        return UIApplication.shared.statusBarFrame.size.height
    }
    
    var currentPage: Int {
        if let vc = viewControllers?[0] as? SingleSubredditViewController {
            return finalSubs.firstIndex(of: vc.sub) ?? 0
        } else {
            return 0
        }
    }
        
    public static var isOffline = false
    var menuB = UIBarButtonItem()
    var drawerButton = UIImageView()
    
    override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if UIColor.isLightTheme && SettingValues.reduceColor {
                        if #available(iOS 13, *) {
                return .darkContent
            } else {
                return .default
            }

        } else {
            return .lightContent
        }
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        return nil
    }

    var alertController: UIAlertController?
    var tempToken: OAuth2Token?

    var currentTitle = "Slide"

    // MARK: - Shared functions
    func didUpdate() {
        let suite = UserDefaults(suiteName: "group.\(self.USR_DOMAIN()).redditslide.prefs")
        suite?.setValue(ReadLater.readLaterIDs.count, forKey: "readlater")
        suite?.synchronize()
        if #available(iOS 14, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "Current_Account")
        }
        
        let count = ReadLater.readLaterIDs.count
        if count > 0 {
            let readLater = UIButton.init(type: .custom)
            readLater.setImage(UIImage(named: "bin")?.navIcon(), for: UIControl.State.normal)
            readLater.addTarget(self, action: #selector(self.showReadLater(_:)), for: UIControl.Event.touchUpInside)
            
            readLaterBadge?.removeFromSuperview()
            readLaterBadge = nil
            
            readLaterBadge = BadgeSwift()
            readLater.addSubview(readLaterBadge!)
            readLaterBadge!.centerXAnchor /==/ readLater.centerXAnchor
            readLaterBadge!.centerYAnchor /==/ readLater.centerYAnchor - 2
            
            readLaterBadge!.text = "\(count)"
            readLaterBadge!.insets = CGSize.zero
            readLaterBadge!.font = UIFont.boldSystemFont(ofSize: 10)
            readLaterBadge!.textColor = SettingValues.reduceColor ? UIColor.navIconColor : UIColor.white
            readLaterBadge!.badgeColor = .clear
            readLaterBadge!.shadowOpacityBadge = 0
            readLater.frame = CGRect.init(x: 0, y: 0, width: 30, height: 44)

            readLaterB = UIBarButtonItem.init(customView: readLater)
            
            navigationItem.rightBarButtonItems = [sortB]
            doLeftItem()

        } else {
            navigationItem.rightBarButtonItems = [sortB]
            doLeftItem()
        }
    }
    
    // from https://github.com/CleverTap/ios-request-review/blob/master/Example/RatingExample/ViewController.swift
    func requestReviewIfAppropriate() {
        if #available(iOS 10.3, *) {
            let lastReviewedVersion = UserDefaults.standard.string(forKey: "lastReviewed")
            let timesOpened = UserDefaults.standard.integer(forKey: "appOpens")
            if lastReviewedVersion != nil && (getVersion() == lastReviewedVersion!) || timesOpened < 10 {
                UserDefaults.standard.set(timesOpened + 1, forKey: "appOpens")
                UserDefaults.standard.synchronize()
                return
            }
            SKStoreReviewController.requestReview()
            UserDefaults.standard.set(0, forKey: "appOpens")
            UserDefaults.standard.set(getVersion(), forKey: "lastReviewed")
            UserDefaults.standard.synchronize()
        } else {
            print("SKStoreReviewController not available")
        }
    }

    func getVersion() -> String {
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        let build = dictionary["CFBundleVersion"] as! String
        return "\(version) build \(build)"
    }

    @objc func onAccountRefreshRequested(_ notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            self?.checkForMail()
        }
    }
    
    func checkSubs() {
        let currentAccount = AccountController.currentName
        if let session = (UIApplication.shared.delegate as! AppDelegate).session {
            Subscriptions.getSubscriptionsFully(session: session, completion: { (newSubs, newMultis) in
                if AccountController.isLoggedIn && currentAccount == AccountController.currentName { // Ensure the user did not switch accounts before applying subs
                    var allSubs = [String]()
                    allSubs.append(contentsOf: newSubs.map { $0.displayName })
                    allSubs.append(contentsOf: newMultis.map { "/m/" + $0.displayName.replacingOccurrences(of: " ", with: "_") })
                    let currentSubs = Subscriptions.subreddits
                    var finalSubs = [String]()
                    finalSubs.append(contentsOf: allSubs)
                    for sub in currentSubs {
                        if !finalSubs.containsIgnoringCase(sub) {
                            finalSubs.append(sub)
                        }
                    }
                    Subscriptions.set(name: currentAccount, subs: finalSubs, completion: {
                    })
                }
            })
        }
    }
    
    func checkForMail() {
        DispatchQueue.main.async {
            // TODO reenable this
            if !self.checkedClipboardOnce && false {
                var clipUrl: URL?
                if let url = UIPasteboard.general.url {
                    if ContentType.getContentType(baseUrl: url) == .REDDIT {
                        clipUrl = url
                    }
                }
                if clipUrl == nil {
                    if let urlS = UIPasteboard.general.string {
                        if let url = URL.init(string: urlS) {
                            if ContentType.getContentType(baseUrl: url) == .REDDIT {
                                clipUrl = url
                            }
                        }
                    }
                }
                
                if clipUrl != nil {
                    self.checkedClipboardOnce = true
                    BannerUtil.makeBanner(text: "Open link from clipboard", color: GMColor.green500Color(), seconds: 5, context: self, top: true, callback: {
                        () in
                        VCPresenter.openRedditLink(clipUrl!.absoluteString, self.navigationController, self)
                    })
                }
            }
            
            if !AccountController.isLoggedIn {
                return
            }
            
            let lastMail = UserDefaults.standard.integer(forKey: "mail")
            let session = (UIApplication.shared.delegate as! AppDelegate).session
            
            do {
                try session?.getProfile({ (result) in
                    switch result {
                    case .failure(let error):
                        print(error)
                    case .success(let profile):
                        AccountController.current = profile
                        SettingValues.nsfwEnabled = profile.over18
                        if let nsfw = UserDefaults.standard.object(forKey: SettingValues.pref_hideNSFWCollection + AccountController.currentName) {
                            SettingValues.hideNSFWCollection = nsfw as! Bool
                        } else {
                            SettingValues.hideNSFWCollection = UserDefaults.standard.bool(forKey: SettingValues.pref_hideNSFWCollection)
                        }
                        if let nsfw = UserDefaults.standard.object(forKey: SettingValues.pref_nsfwPreviews + AccountController.currentName) {
                            SettingValues.nsfwPreviews = nsfw as! Bool
                        } else {
                            SettingValues.nsfwPreviews = UserDefaults.standard.bool(forKey: SettingValues.pref_nsfwPreviews)
                        }
                        
                        let unread = profile.inboxCount
                        let diff = unread - lastMail
                        if profile.isMod && AccountController.modSubs.isEmpty {
                            print("Getting mod subs")
                            AccountController.doModOf()
                        }
                        DispatchQueue.main.async {
                            if diff > 0 {
                                let suite = UserDefaults(suiteName: "group.\(self.USR_DOMAIN()).redditslide.prefs")
                                suite?.setValue(AccountController.current?.inboxCount ?? 0, forKey: "inbox")
                                suite?.synchronize()
                                
                                if #available(iOS 14, *) {
                                    WidgetCenter.shared.reloadTimelines(ofKind: "Current_Account")
                                }
                                
                                BannerUtil.makeBanner(text: "\(diff) new message\(diff > 1 ? "s" : "")!", seconds: 5, context: self, top: true, callback: {
                                    () in
                                    let inbox = InboxViewController.init()
                                    VCPresenter.showVC(viewController: inbox, popupIfPossible: false, parentNavigationController: self.navigationController, parentViewController: self)
                                })
                            }
                            UserDefaults.standard.set(unread, forKey: "mail")
                            NotificationCenter.default.post(name: .onAccountMailCountChanged, object: nil, userInfo: [
                                "Count": unread,
                                ])
                            UserDefaults.standard.synchronize()
                        }
                    }
                })
            } catch {
                
            }
        }
    }

    func setToken(token: OAuth2Token) {
        print("Setting token")
        alertController?.dismiss(animated: false, completion: nil)
        // Do any additional setup after loading the view.
        
        if UserDefaults.standard.array(forKey: "subs" + token.name) != nil {
            UserDefaults.standard.set(token.name, forKey: "name")
            UserDefaults.standard.synchronize()
            tempToken = token
            AccountController.switchAccount(name: token.name)
            (UIApplication.shared.delegate as! AppDelegate).syncColors(subredditController: self)
        } else {
            alertController = UIAlertController(title: "Syncing subscriptions...\n\n\n", message: nil, preferredStyle: .alert)
            
            let spinnerIndicator = UIActivityIndicatorView(style: .whiteLarge)
            UserDefaults.standard.setValue(true, forKey: "done" + token.name)
            spinnerIndicator.center = CGPoint(x: 135.0, y: 65.5)
            spinnerIndicator.color = UIColor.fontColor
            spinnerIndicator.startAnimating()
            
            alertController?.view.addSubview(spinnerIndicator)
            self.present(alertController!, animated: true, completion: nil)
            UserDefaults.standard.set(token.name, forKey: "name")
            UserDefaults.standard.synchronize()
            tempToken = token
            
            AccountController.switchAccount(name: token.name)
            (UIApplication.shared.delegate as! AppDelegate).syncColors(subredditController: self)
        }
    }
    
    func complete(subs: [String]) {
        var finalSubs = subs
        if !subs.contains("slide_ios") {
            self.alertController?.dismiss(animated: true, completion: {
                let alert = UIAlertController.init(title: "Subscribe to r/slide_ios?", message: "Would you like to subscribe to the Slide for Reddit iOS community and receive news and updates first?", preferredStyle: .alert)
                alert.addAction(UIAlertAction.init(title: "No.", style: .cancel, handler: {(_) in
                    self.finalizeSetup(subs)
                }))
                alert.addAction(UIAlertAction.init(title: "Sure!", style: .default, handler: {(_) in
                    finalSubs.insert("slide_ios", at: 2)
                    self.finalizeSetup(finalSubs)
                    do {
                        try (UIApplication.shared.delegate as! AppDelegate).session!.setSubscribeSubreddit(Subreddit.init(subreddit: "slide_ios"), subscribe: true, completion: { (_) in
                            
                        })
                    } catch {
                        
                    }
                }))
                self.present(alert, animated: true, completion: nil)
            })
        } else {
            if self.alertController != nil {
                self.alertController?.dismiss(animated: true, completion: {
                    self.finalizeSetup(subs)
                })
            } else {
                self.finalizeSetup(subs)
            }
        }
    }
    
    func finalizeSetup(_ subs: [String]) {
        Subscriptions.set(name: (tempToken?.name)!, subs: subs, completion: {
            self.hardReset()
        })
    }
    
    func setupTabBar(_ subs: [String]) {
        if !SettingValues.subredditBar {
            return
        }
        let oldOffset = tabBar?.collectionView.contentOffset ?? CGPoint.zero
        tabBar?.removeFromSuperview()
        tabBar = SubredditPagingTitleCollectionView(withSubreddits: subs, delegate: self)
        self.navigationItem.titleView = tabBar
        tabBar.sizeToFit()
        tabBar.collectionView.setNeedsLayout()
        tabBar.collectionView.setNeedsDisplay()
        if let nav = self.navigationController as? SwipeForwardNavigationController {
            nav.fullWidthBackGestureRecognizer.require(toFail: tabBar.collectionView.panGestureRecognizer)
        }
        matchScroll(scrollView: tabBar.collectionView)
        for view in self.view.subviews {
            if !(view is UICollectionView) {
                if let scrollView = view as? UIScrollView {
                    tabBar.parentScroll = scrollView
                }
            }
        }
        tabBar.collectionView.contentOffset = oldOffset
    }
    
    func didChooseSub(_ gesture: UITapGestureRecognizer) {
        let sub = gesture.view!.tag
        goToSubreddit(index: sub)
    }
    
    func doToolbarOffset() {
        guard let tabBar = tabBar else { return }
        var currentBackgroundOffset = tabBar.collectionView.contentOffset
        
        let layout = (tabBar.collectionView.collectionViewLayout as! WrappingHeaderFlowLayout)

        let currentWidth = layout.widthAt(currentIndex)
        
        let insetX = (tabBar.collectionView.superview!.frame.origin.x / 2) - ((tabBar.collectionView.superview!.frame.maxX - tabBar.collectionView.superview!.frame.size.width) / 2) // Collectionview left offset for profile icon

        let offsetX = layout.offsetAt(currentIndex - 1) + // Width of all cells to left
            (currentWidth / 2) - // Width of current cell
            (self.tabBar!.collectionView.frame.size.width / 2) +
            insetX -
            (12)
        
        currentBackgroundOffset.x = offsetX
        self.tabBar.collectionView.contentOffset = currentBackgroundOffset
        // self.tabBar.collectionView.layoutIfNeeded()
    }
    
    func goToSubreddit(index: Int) {
        let firstViewController = SingleSubredditViewController(subName: finalSubs[index], parent: self)
        
        weak var weakPageVc = self

        setViewControllers([firstViewController],
                           direction: .forward,
                           animated: false,
                           completion: { (_) in
                                guard let pageVc = weakPageVc else {
                                    return
                                }

                                DispatchQueue.main.async {
                                    pageVc.doCurrentPage(index)
                                }
                            })
    }
    
    func doLogin(token: OAuth2Token?, register: Bool) {
        (UIApplication.shared.delegate as! AppDelegate).login = self
        if token == nil {
            AccountController.addAccount(context: self, register: register)
        } else {
            setToken(token: token!)
        }
    }

    func doLeftItem() {
        let label = UILabel()
        label.text = "   \(SettingValues.reduceColor ? "      " : "")\(SettingValues.subredditBar ? "" : self.currentTitle)"
        label.textColor = SettingValues.reduceColor ? UIColor.fontColor : .white
        label.adjustsFontSizeToFitWidth = true
        label.font = UIFont.boldSystemFont(ofSize: 20)
        
        if SettingValues.reduceColor {
            let sideView = UIImageView(frame: CGRect(x: 5, y: 5, width: 30, height: 30))
            let subreddit = self.currentTitle
            sideView.backgroundColor = ColorUtil.getColorForSub(sub: subreddit)
            
            if let icon = Subscriptions.icon(for: subreddit) {
                sideView.contentMode = .scaleAspectFill
                sideView.image = UIImage()
                sideView.sd_setImage(with: URL(string: icon.unescapeHTML), completed: nil)
            } else {
                sideView.contentMode = .center
                if subreddit.contains("m/") {
                    sideView.image = SubredditCellView.defaultIconMulti
                } else if subreddit.lowercased() == "all" {
                    sideView.image = SubredditCellView.allIcon
                    sideView.backgroundColor = GMColor.blue500Color()
                } else if subreddit.lowercased() == "frontpage" {
                    sideView.image = SubredditCellView.frontpageIcon
                    sideView.backgroundColor = GMColor.green500Color()
                } else if subreddit.lowercased() == "popular" {
                    sideView.image = SubredditCellView.popularIcon
                    sideView.backgroundColor = GMColor.purple500Color()
                } else {
                    sideView.image = SubredditCellView.defaultIcon
                }
            }
            
            label.addSubview(sideView)
            sideView.sizeAnchors /==/ CGSize.square(size: 30)
            sideView.centerYAnchor /==/ label.centerYAnchor
            sideView.leftAnchor /==/ label.leftAnchor

            sideView.layer.cornerRadius = 15
            sideView.clipsToBounds = true
        }
        
        label.sizeToFit()
        if !SettingValues.subredditBar {
            self.navigationItem.titleView = label
        }
                
        self.navigationItem.setHidesBackButton(true, animated: false)
        self.splitViewController?.navigationItem.setHidesBackButton(true, animated: false)
        self.navigationItem.leftBarButtonItem = accountB
    }
    
    @objc func popToPrimary(_ sender: AnyObject) {
        if let split = splitViewController, split.isCollapsed {
            if let nav = split.viewControllers[0] as? UINavigationController {
                nav.popToRootViewController(animated: true)
            }
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return UIResponder.isFirstResponderTextField ? nil : [
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(spacePressed)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(spacePressed)),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(spacePressedUp)),
            UIKeyCommand(input: "s", modifierFlags: .command, action: #selector(search), discoverabilityTitle: "Search"),
            UIKeyCommand(input: "p", modifierFlags: .command, action: #selector(hideReadPosts), discoverabilityTitle: "Hide read posts"),
            UIKeyCommand(input: "r", modifierFlags: .command, action: #selector(refresh), discoverabilityTitle: "Reload"),
        ]
    }
    
    @objc func spacePressed() {
        UIView.animate(withDuration: 0.2, delay: 0, options: UIView.AnimationOptions.curveEaseOut, animations: {
            if let vc = self.getSubredditVC() {
                vc.tableView.contentOffset.y = min(vc.tableView.contentOffset.y + 350, vc.tableView.contentSize.height - vc.tableView.frame.size.height)
            }
        }, completion: nil)
    }

    @objc func spacePressedUp() {
        UIView.animate(withDuration: 0.2, delay: 0, options: UIView.AnimationOptions.curveEaseOut, animations: {
            if let vc = self.getSubredditVC() {
                vc.tableView.contentOffset.y = max(vc.tableView.contentOffset.y - 350, -64)
            }
        }, completion: nil)
    }

    @objc func search() {
        if let vc = self.getSubredditVC() {
            vc.search()
        }
    }

    @objc func hideReadPosts() {
        if let vc = self.getSubredditVC() {
            vc.hideReadPosts()
        }
    }

    @objc func refresh() {
        if let vc = self.getSubredditVC() {
            vc.refresh()
        }
    }

    @objc public func onAccountChangedNotificationPosted() {
        DispatchQueue.main.async { [weak self] in
            self?.doProfileIcon()
        }
    }

    @objc func screenEdgeSwiped() {
        switch SettingValues.sideGesture {
        case .SUBS:()
            // TODO show sidebar
        case .INBOX:
            self.showCurrentAccountMenu(nil)
        case .POST:
            if let vc = self.viewControllers?[0] as? SingleSubredditViewController {
                vc.newPost(self)
            }
        case .SIDEBAR:
            if let vc = self.viewControllers?[0] as? SingleSubredditViewController {
                vc.doDisplaySidebar()
            }
        case .NONE:
            return
        }
    }
    
    func doProfileIcon() {
        let account = ExpandedHitButton(type: .custom)
        let accountImage = UIImage(sfString: SFSymbol.personCropCircle, overrideString: "profile")?.navIcon()
        if let image = AccountController.current?.image, let imageUrl = URL(string: image) {
            account.sd_setImage(with: imageUrl, for: .normal, placeholderImage: accountImage, options: [.allowInvalidSSLCertificates], context: nil, progress: nil) { (image, _, _, _) in
                if #available(iOS 14.0, *) {
                    let suite = UserDefaults(suiteName: "group.\(self.USR_DOMAIN()).redditslide.prefs")
                    suite?.setValue(AccountController.currentName, forKey: "current_account")
                    suite?.setValue(AccountController.current?.inboxCount ?? 0, forKey: "inbox")
                    suite?.setValue((AccountController.current?.commentKarma ?? 0) + (AccountController.current?.linkKarma ?? 0), forKey: "karma")
                                        
                    if let data = image?.pngData() {
                        suite?.setValue(data, forKey: "profile_icon")
                    }
                    suite?.synchronize()
                }
            }
        } else {
            account.setImage(accountImage, for: UIControl.State.normal)
        }
        
        account.layer.cornerRadius = 5
        account.clipsToBounds = true
        account.contentMode = .scaleAspectFill
        account.addTarget(self, action: #selector(self.showCurrentAccountMenu(_:)), for: UIControl.Event.touchUpInside)
        account.frame = CGRect.init(x: 0, y: 0, width: 30, height: 30)
        account.sizeAnchors /==/ CGSize.square(size: 30)
        accountB = UIBarButtonItem(customView: account)
        accountB.accessibilityIdentifier = "Account button"
        accountB.accessibilityLabel = "Account"
        accountB.accessibilityHint = "Open account page"
        if #available(iOS 13, *), self is SplitMainViewController {
            let interaction = UIContextMenuInteraction(delegate: self as! SplitMainViewController)
            self.accountB.customView?.addInteraction(interaction)
        }
        didUpdate()
    }

    @objc public func handleCloseNav(controller: UIButtonWithContext) {
        controller.parentController?.dismiss(animated: true, completion: nil)
    }

    func checkForUpdate() {
        if !SettingValues.done7() || !SettingValues.doneVersion() {
            if !SettingValues.done7() {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                    let viewController = OnboardingViewController()
                    viewController.view.backgroundColor = OnboardingViewController.versionBackgroundColor
                    let newParent = TapBehindModalViewController.init(rootViewController: viewController)
                    newParent.navigationBar.shadowImage = UIImage()
                    newParent.navigationBar.isTranslucent = false
                    newParent.navigationBar.barTintColor = OnboardingViewController.versionBackgroundColor
                    newParent.navigationBar.shadowImage = UIImage()
                    newParent.navigationBar.setBackgroundImage(UIImage(), for: .default)

                    if #available(iOS 13, *) {
                        let navBarAppearance = UINavigationBarAppearance()
                        navBarAppearance.configureWithOpaqueBackground()
                        navBarAppearance.shadowColor = .clear
                        navBarAppearance.shadowImage = UIImage()
                        navBarAppearance.backgroundColor = OnboardingViewController.versionBackgroundColor
                        newParent.navigationBar.standardAppearance = navBarAppearance
                        newParent.navigationBar.scrollEdgeAppearance = navBarAppearance
                    }
                    
                    let button = UIButtonWithContext.init(type: .custom)
                    button.parentController = newParent
                    button.imageView?.contentMode = UIView.ContentMode.scaleAspectFit
                    button.setImage(UIImage(sfString: SFSymbol.xmark, overrideString: "close")!.navIcon(), for: UIControl.State.normal)
                    button.frame = CGRect.init(x: 0, y: 0, width: 40, height: 40)
                    button.addTarget(self, action: #selector(self.handleCloseNav(controller:)), for: .touchUpInside)

                    let barButton = UIBarButtonItem.init(customView: button)
                    barButton.customView?.frame = CGRect.init(x: 0, y: 0, width: 40, height: 40)
                    newParent.modalPresentationStyle = .pageSheet

                    viewController.navigationItem.rightBarButtonItems = [barButton]

                    self.present(newParent, animated: true, completion: nil)
                }
            }

            let session = (UIApplication.shared.delegate as! AppDelegate).session
            do {
                try session?.getList(Paginator.init(), subreddit: Subreddit.init(subreddit: "slide_ios"), sort: LinkSortType.hot, timeFilterWithin: TimeFilterWithin.hour, completion: { (result) in
                    switch result {
                    case .failure:
                        // Ignore this
                        break
                    case .success(let listing):
                        let settings = UserDefaults.standard

                        let submissions = listing.children.compactMap({ $0 as? Link })
                        if submissions.count < 2 {
                            return
                        }
                        
                        let first = submissions[0]
                        let second = submissions[1]
                        var storedTitle = ""
                        var storedLink = ""
                        
                        let g1 = first.title.capturedGroups(withRegex: "(\\d+(\\.\\d+)+)")
                        let g2 = second.title.capturedGroups(withRegex: "(\\d+(\\.\\d+)+)")
                        let lastUpdate = g1.isEmpty ? (g2.isEmpty ? "" : g2[0][0]) : g1[0][0]
                        
                        if first.stickied && first.title.contains(Bundle.main.releaseVersionNumber!) {
                            storedTitle = first.title
                            storedLink = first.permalink
                        } else if second.stickied && second.title.contains(Bundle.main.releaseVersionNumber!) {
                            storedTitle = second.title
                            storedLink = second.permalink
                        } else if Bundle.main.releaseVersionNumber!.contains(lastUpdate) || Bundle.main.releaseVersionNumber!.contains(lastUpdate) {
                            storedTitle = g1.isEmpty ? second.title : first.title
                            storedLink = g1.isEmpty ? second.permalink : first.permalink
                            
                            UserDefaults.standard.set(true, forKey: Bundle.main.releaseVersionNumber!)
                            UserDefaults.standard.synchronize()
                        }
                        
                        if !storedTitle.isEmpty && !storedLink.isEmpty {
                            
                            settings.set(storedTitle, forKey: "vtitle")
                            settings.set(storedLink, forKey: "vlink")
                            if SettingValues.done7() && !SettingValues.doneVersion() {
                                DispatchQueue.main.async {
                                    SettingValues.showVersionDialog(storedTitle, submissions[0], parentVC: self)
                                }
                            }
                            settings.set(true, forKey: Bundle.main.releaseVersionNumber!)
                        } else {
                            settings.set(true, forKey: Bundle.main.releaseVersionNumber!)
                        }
                    }
                })
            } catch {
            }
        }
    }
    @objc func showSortMenu(_ sender: UIButton?) {
        getSubredditVC()?.showSortMenu(sender)
    }
    
    @objc func showReadLater(_ sender: UIButton?) {
        VCPresenter.showVC(viewController: ReadLaterViewController(subreddit: currentTitle), popupIfPossible: false, parentNavigationController: self.navigationController, parentViewController: self)
    }

    @objc func showCurrentAccountMenu(_ sender: UIButton?) {
        // TODO check for view controller count
        if let parent = self.parent {
            parent.navigationController?.popViewController(animated: true)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func getSubredditVC() -> SingleSubredditViewController? {
        if finalSubs.count < currentIndex || finalSubs.isEmpty {
            return (viewControllers?.count ?? 0) == 0 ? nil : viewControllers?.first as? SingleSubredditViewController
        }
        let currentSub = finalSubs[currentIndex]
        return viewControllers?
            .compactMap({ $0 as? SingleSubredditViewController })
            .first(where: { $0.sub == currentSub })
    }
    func shadowbox() {
        getSubredditVC()?.shadowboxMode()
    }
    
    @objc func showMenu(_ sender: AnyObject) {
        getSubredditVC()?.showMore(sender, parentVC: self)
    }
    // MARK: - Overrides
    func handleToolbars() {
    }
    
    func redoSubs() {
    }
    
    func doRetheme() {
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        hasAppeared = true
    }
    
    public func viewWillAppearActions(override: Bool = false) {
    }
    
    func hardReset(soft: Bool = false) {
    }

    func addAccount(register: Bool) {
    }
    
    func doAddAccount(register: Bool) {
    }

    func addAccount(token: OAuth2Token, register: Bool) {
    }
    
    func goToSubreddit(subreddit: String, override: Bool = false) {
    }
    
    func goToUser(profile: String) {
    }

    func makeMenuNav() {
    }
    
    @objc func restartVC() {
    }
    
    func doCurrentPage(_ page: Int) {
    }
    
    func doButtons() {
    }
    
    func colorChanged(_ color: UIColor) {
    }
    
    @objc func showDrawer(_ sender: AnyObject) {
    }
}

extension MainViewController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        var index = finalSubs.firstIndex(of: (viewController as! SingleSubredditViewController).sub)
        if let vc = viewController as? SingleSubredditViewController {
            index = finalSubs.firstIndex(of: vc.sub)
        }
        guard let viewControllerIndex = index else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0 else {
            return nil
        }
        
        guard finalSubs.count > previousIndex else {
            return nil
        }
        
        return SingleSubredditViewController(subName: finalSubs[previousIndex], parent: self)
    }
        
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = finalSubs.firstIndex(of: (viewController as! SingleSubredditViewController).sub) else {
            return nil
        }
        
        let nextIndex = viewControllerIndex + 1
        let orderedViewControllersCount = finalSubs.count
        
        guard orderedViewControllersCount != nextIndex else {
            return nil
        }
        
        guard orderedViewControllersCount > nextIndex else {
            return nil
        }
        
        return SingleSubredditViewController(subName: finalSubs[nextIndex], parent: self)
    }
    
}

extension MainViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        let page = finalSubs.firstIndex(of: (self.viewControllers!.first as! SingleSubredditViewController).sub)
        //        let page = tabBar.items.index(of: tabBar.selectedItem!)
        // TODO: - Crashes here
        guard page != nil else {
            return
        }

        doCurrentPage(page!)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        let pendingSub = (pendingViewControllers[0] as! SingleSubredditViewController).sub
        let prevSub = getSubredditVC()?.sub ?? ""
        color2 = ColorUtil.getColorForSub(sub: pendingSub, true)
        color1 = ColorUtil.getColorForSub(sub: prevSub, true)
    }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
    var releaseVersionNumberPretty: String {
        return "v\(releaseVersionNumber ?? "1.0.0")"
    }
}

class ExpandedHitButton: UIButton {
    override func point( inside point: CGPoint, with event: UIEvent? ) -> Bool {
        let relativeFrame = self.bounds
        let hitTestEdgeInsets = UIEdgeInsets( top: -44, left: -44, bottom: -44, right: -44 )
        let hitFrame = relativeFrame.inset(by: hitTestEdgeInsets)
        return hitFrame.contains(point)
    }
}

class ExpandedHitTestButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.insetBy(dx: -20, dy: -20).contains(point)
    }
}

@available(iOS 13.0, *)
extension SplitMainViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
                return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in

            return self.makeContextMenu()
        })

    }
    func makeContextMenu() -> UIMenu {

        // Create a UIAction for sharing
        var buttons = [UIAction]()
        for accountName in AccountController.names.unique().sorted() {
            if accountName == AccountController.currentName {
                buttons.append(UIAction(title: accountName, image: UIImage(sfString: SFSymbol.checkmarkCircle, overrideString: "selected")!.menuIcon(), handler: { (_) in
                }))
            } else {
                buttons.append(UIAction(title: accountName, image: nil, handler: { (_) in
                    self.navigation(nil, didRequestAccountChangeToName: accountName)
                }))
            }
        }

        // Create and return a UIMenu with the share action
        return UIMenu(title: "Switch Accounts", children: buttons)
    }

}

extension Array where Element == String {
    func containsIgnoringCase(_ element: Element) -> Bool {
        contains { $0.caseInsensitiveCompare(element) == .orderedSame }
    }
}
