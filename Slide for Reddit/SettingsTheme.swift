//
//  SettingsTheme.swift
//  Slide for Reddit
//
//  Created by Carlos Crane on 1/21/17.
//  Copyright © 2017 Haptic Apps. All rights reserved.
//

import Anchorage
import MKColorPicker
import RLBAlertsPickers
import SDCAlertView
import UIKit

class SettingsTheme: BubbleSettingTableViewController, ColorPickerViewDelegate {

    var tochange: SettingsViewController?
    var primary: UITableViewCell = InsetCell.init(style: .subtitle, reuseIdentifier: "primary")
    var accent: UITableViewCell = InsetCell()
    var base: UITableViewCell = InsetCell()
    var night: UITableViewCell = InsetCell(style: .subtitle, reuseIdentifier: "night")
    var tintingMode: UITableViewCell = InsetCell.init(style: .subtitle, reuseIdentifier: "tintingMode")
    var tintOutside: UITableViewCell = InsetCell()
    var tintOutsideSwitch: UISwitch = UISwitch()
    var custom: UITableViewCell = InsetCell()

    var shareButton = UIBarButtonItem.init()

    var reduceColorCell: UITableViewCell = InsetCell.init(style: .subtitle, reuseIdentifier: "reduce")
    var reduceColor: UISwitch = UISwitch()
    var nightEnabled: UISwitch = UISwitch()

    var isAccent = false
    
    var titleLabel = UILabel()

    var accentChosen: UIColor?
    var primaryChosen: UIColor?
    
    var customThemes: [ColorUtil.Theme] = []
    var themes: [ColorUtil.Theme] = []

    public func colorPickerView(_ colorPickerView: ColorPickerView, didSelectItemAt indexPath: IndexPath) {
        if isAccent {
            accentChosen = colorPickerView.colors[indexPath.row]
            titleLabel.textColor = self.accentChosen
            self.accent.imageView?.image = UIImage(named: "circle")?.toolbarIcon().getCopy(withColor: accentChosen!)
            reduceColor.onTintColor = accentChosen!
            tableView.beginUpdates()
            tableView.endUpdates()
        } else {
            primaryChosen = colorPickerView.colors[indexPath.row]
            setupBaseBarColors(primaryChosen)
            self.primary.imageView?.image = UIImage(named: "circle")?.toolbarIcon().getCopy(withColor: primaryChosen!)
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? InsetCell {
            if indexPath.row == 0 {
                cell.top = true
            } else {
                cell.top = false
            }
            if indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 || indexPath.section == 1 || indexPath.section == 2 {
                cell.bottom = true
            } else {
                cell.bottom = false
            }
        }
    }

    func pickPrimary() {
        isAccent = false
        if #available(iOS 14, *) {
            let vc = UIColorPickerViewController()
            vc.title = "Default subreddit color"
            vc.supportsAlpha = false
            vc.selectedColor = ColorUtil.baseColor
            vc.delegate = self
            present(vc, animated: true)
        } else {
            let alertController = UIAlertController(title: "\n\n\n\n\n\n\n\n", message: nil, preferredStyle: UIAlertController.Style.actionSheet)
            let margin: CGFloat = 10.0
            let rect = CGRect(x: margin, y: margin, width: UIDevice.current.respectIpadLayout() ? 314 - margin * 4.0: UIScreen.main.bounds.size.width - margin * 4.0, height: 200)
            let MKColorPicker = ColorPickerView.init(frame: rect)
            MKColorPicker.delegate = self
            MKColorPicker.colors = GMPalette.allColor()
            MKColorPicker.selectionStyle = .check
            MKColorPicker.scrollDirection = .vertical
            let firstColor = ColorUtil.baseColor
            for i in 0 ..< MKColorPicker.colors.count {
                if MKColorPicker.colors[i].cgColor.__equalTo(firstColor.cgColor) {
                    MKColorPicker.preselectedIndex = i
                    break
                }
            }

            MKColorPicker.style = .circle

            alertController.view.addSubview(MKColorPicker)

            let somethingAction = UIAlertAction(title: "Save", style: .default, handler: { (_: UIAlertAction!) in
                if self.primaryChosen != nil {
                    UserDefaults.standard.setColor(color: self.primaryChosen!, forKey: "basecolor")
                    UserDefaults.standard.synchronize()
                }

                UserDefaults.standard.setColor(color: (self.navigationController?.navigationBar.barTintColor)!, forKey: "basecolor")
                UserDefaults.standard.synchronize()
                _ = ColorUtil.doInit()
            })

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_: UIAlertAction!) in
                self.setupBaseBarColors()
                self.primary.imageView?.image = UIImage(named: "circle")?.toolbarIcon().getCopy(withColor: ColorUtil.baseColor)
            })

            alertController.addAction(somethingAction)
            alertController.addAction(cancelAction)
            if UIDevice.current.respectIpadLayout() {
                alertController.preferredContentSize = CGSize(width: MKColorPicker.bounds.size.width + (margin * 2), height: MKColorPicker.bounds.size.height + 100)
            }

            alertController.modalPresentationStyle = .popover
            if let presenter = alertController.popoverPresentationController {
                presenter.sourceView = selectedTableView
                presenter.sourceRect = selectedTableView.bounds
            }

            present(alertController, animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section > 0 {
            return 60
        } else {
            return UITableView.automaticDimension
        }
    }

    func redoThemes() {
        self.customThemes.removeAll()
        self.themes.removeAll()
        
        for theme in ColorUtil.themes {
            if theme.isCustom {
                customThemes.append(theme)
            } else {
                themes.append(theme)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        redoThemes()
        self.tableView.register(ThemeCellView.classForCoder(), forCellReuseIdentifier: "theme")
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsThemeNeedsRestart), name: .settingsThemeNeedsRestart, object: nil)
    }

    func pickAccent() {
        self.isAccent = true
        if #available(iOS 14, *) {
            let vc = UIColorPickerViewController()
            vc.title = "Default accent color"
            vc.supportsAlpha = false
            vc.selectedColor = ColorUtil.baseAccent
            vc.delegate = self
            present(vc, animated: true)
        } else {
            let alertController = UIAlertController(title: "\n\n\n\n\n\n\n\n", message: nil, preferredStyle: UIAlertController.Style.actionSheet)

            let margin: CGFloat = 10.0
            let rect = CGRect(x: margin, y: margin, width: UIDevice.current.respectIpadLayout() ? 314 - margin * 4.0: alertController.view.bounds.size.width - margin * 4.0, height: 200)
            let MKColorPicker = ColorPickerView.init(frame: rect)
            MKColorPicker.delegate = self
            MKColorPicker.colors = GMPalette.allColorAccent()
            MKColorPicker.selectionStyle = .check

            MKColorPicker.scrollDirection = .vertical
            let firstColor = ColorUtil.baseColor
            for i in 0 ..< MKColorPicker.colors.count {
                if MKColorPicker.colors[i].cgColor.__equalTo(firstColor.cgColor) {
                    MKColorPicker.preselectedIndex = i
                    break
                }
            }

            MKColorPicker.style = .circle

            alertController.view.addSubview(MKColorPicker)

            let somethingAction = UIAlertAction(title: "Save", style: .default, handler: { (_: UIAlertAction!) in
                if self.accentChosen != nil {
                    UserDefaults.standard.setColor(color: self.accentChosen!, forKey: "accentcolor")
                    UserDefaults.standard.synchronize()
                    _ = ColorUtil.doInit()
                    self.titleLabel.textColor = self.accentChosen!
                    self.tochange!.tableView.reloadData()
                    self.setupViews()
                    self.tochange!.doCells()
                    self.tochange!.tableView.reloadData()
                    self.tableView.reloadData()
                }
            })

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_: UIAlertAction!) in
                self.accentChosen = nil
                self.reduceColor.onTintColor = ColorUtil.baseAccent
                self.titleLabel.textColor = ColorUtil.baseAccent
                self.accent.imageView?.image = UIImage(named: "circle")?.toolbarIcon().getCopy(withColor: ColorUtil.baseAccent)
            })

            alertController.addAction(somethingAction)
            alertController.addAction(cancelAction)
            alertController.modalPresentationStyle = .popover
            if UIDevice.current.respectIpadLayout() {
                alertController.preferredContentSize = CGSize(width: MKColorPicker.bounds.size.width + (margin * 2), height: MKColorPicker.bounds.size.height + 100)
            }
            if let presenter = alertController.popoverPresentationController {
                presenter.sourceView = selectedTableView
                presenter.sourceRect = selectedTableView.bounds
            }

            present(alertController, animated: true, completion: nil)
        }
    }

    public func createCell(_ cell: UITableViewCell, _ switchV: UISwitch? = nil, isOn: Bool, text: String) {
        cell.textLabel?.text = text
        cell.textLabel?.textColor = UIColor.fontColor
        cell.backgroundColor = UIColor.foregroundColor
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = .byWordWrapping
        if let s = switchV {
            s.isOn = isOn
            s.addTarget(self, action: #selector(SettingsLayout.switchIsChanged(_:)), for: UIControl.Event.valueChanged)
            cell.accessoryView = s
        }
        cell.selectionStyle = UITableViewCell.SelectionStyle.none
    }

    var doneOnce = false
    
    @objc func onSettingsThemeNeedsRestart() {
        self.setupViews()
        self.redoThemes()
        self.tochange!.doCells()
        self.tochange!.tableView.reloadData()
        self.tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupBaseBarColors()
        if doneOnce {
            onSettingsThemeNeedsRestart()
        } else {
            doneOnce = true
        }
    }

    override func loadView() {
        super.loadView()
        setupViews()
    }
    
    func setupViews() {
        self.automaticallyAdjustsScrollViewInsets = false
        self.edgesForExtendedLayout = UIRectEdge.all
        self.extendedLayoutIncludesOpaqueBars = true
        
        self.view.backgroundColor = UIColor.backgroundColor
        // set the title
        self.title = "App Theme"
        self.headers = ["App colors", "Night mode", "Custom themes", "Standard themes"]
        self.tableView.separatorStyle = .none
        
        self.primary.textLabel?.text = "Default subreddit color"
        self.primary.accessoryType = .none
        self.primary.backgroundColor = UIColor.foregroundColor
        self.primary.textLabel?.textColor = UIColor.fontColor
        self.primary.imageView?.image = UIImage(named: "circle")?.toolbarIcon().getCopy(withColor: ColorUtil.baseColor)

        self.accent.textLabel?.text = "Default accent color"
        self.accent.accessoryType = .none
        self.accent.backgroundColor = UIColor.foregroundColor
        self.accent.textLabel?.textColor = UIColor.fontColor
        self.accent.imageView?.image = UIImage(named: "circle")?.toolbarIcon().getCopy(withColor: ColorUtil.baseAccent)
        self.accent.detailTextLabel?.textColor = UIColor.fontColor
        self.accent.detailTextLabel?.numberOfLines = 0
        self.accent.detailTextLabel?.text = "Applies to links and buttons"

        self.custom.textLabel?.text = "New custom theme"
        self.custom.accessoryType = .disclosureIndicator
        self.custom.backgroundColor = UIColor.foregroundColor
        self.custom.textLabel?.textColor = UIColor.fontColor
        self.custom.imageView?.image = UIImage(named: "palette")?.toolbarIcon().withRenderingMode(.alwaysTemplate)
        self.custom.imageView?.tintColor = UIColor.navIconColor
        
        self.base.textLabel?.text = "Base theme"
        self.base.accessoryType = .disclosureIndicator
        self.base.backgroundColor = UIColor.foregroundColor
        self.base.textLabel?.textColor = UIColor.fontColor
        self.base.imageView?.image = UIImage(named: "palette")?.toolbarIcon().withRenderingMode(.alwaysTemplate)
        self.base.imageView?.tintColor = UIColor.navIconColor
        
        nightEnabled = UISwitch().then {
            $0.onTintColor = ColorUtil.baseAccent
        }
        nightEnabled.isOn = SettingValues.nightModeEnabled
        nightEnabled.addTarget(self, action: #selector(SettingsViewController.switchIsChanged(_:)), for: UIControl.Event.valueChanged)
        self.night.textLabel?.text = "Night Mode"
        if #available(iOS 13, *) {
            self.night.detailTextLabel?.text = "Night mode follows iOS Dark Mode automatically"
        } else {
            self.night.detailTextLabel?.text = "Tap to change night hours"
        }
        self.night.detailTextLabel?.textColor = UIColor.fontColor
        self.night.accessoryType = .none
        self.night.backgroundColor = UIColor.foregroundColor
        self.night.textLabel?.textColor = UIColor.fontColor
        self.night.imageView?.image = UIImage(sfString: SFSymbol.moonStarsFill, overrideString: "night")?.toolbarIcon().withRenderingMode(.alwaysTemplate)
        self.night.imageView?.tintColor = UIColor.navIconColor
        night.accessoryView = nightEnabled

        tintOutsideSwitch = UISwitch().then {
            $0.onTintColor = ColorUtil.baseAccent
        }
        
        tintOutsideSwitch.isOn = SettingValues.onlyTintOutside
        tintOutsideSwitch.addTarget(self, action: #selector(SettingsTheme.switchIsChanged(_:)), for: UIControl.Event.valueChanged)
        self.tintOutside.textLabel?.text = "Only tint outside of subreddit"
        self.tintOutside.accessoryView = tintOutsideSwitch
        self.tintOutside.backgroundColor = UIColor.foregroundColor
        self.tintOutside.textLabel?.textColor = UIColor.fontColor
        tintOutside.selectionStyle = UITableViewCell.SelectionStyle.none
        
        self.tintingMode.textLabel?.text = "Subreddit tinting mode"
        self.tintingMode.detailTextLabel?.text = SettingValues.tintingMode
        self.tintingMode.backgroundColor = UIColor.foregroundColor
        self.tintingMode.textLabel?.textColor = UIColor.fontColor
        self.tintingMode.detailTextLabel?.textColor = UIColor.fontColor
        
        reduceColor = UISwitch().then {
            $0.onTintColor = ColorUtil.baseAccent
        }

        reduceColor.isOn = SettingValues.reduceColor
        reduceColor.addTarget(self, action: #selector(SettingsViewController.switchIsChanged(_:)), for: UIControl.Event.valueChanged)
        reduceColorCell.textLabel?.text = "Minimal Mode"
        reduceColorCell.textLabel?.numberOfLines = 0
        reduceColorCell.detailTextLabel?.text = "Disables header colors for a simpler look"
        reduceColorCell.detailTextLabel?.numberOfLines = 0
        reduceColorCell.accessoryView = reduceColor
        reduceColorCell.backgroundColor = UIColor.foregroundColor
        reduceColorCell.textLabel?.textColor = UIColor.fontColor
        reduceColorCell.detailTextLabel?.textColor = UIColor.fontColor
        reduceColorCell.selectionStyle = UITableViewCell.SelectionStyle.none
        self.reduceColorCell.imageView?.image = UIImage(sfString: SFSymbol.circleLefthalfFill, overrideString: "nocolors")?.toolbarIcon()
        self.reduceColorCell.imageView?.tintColor = UIColor.fontColor
                
        createCell(reduceColorCell, reduceColor, isOn: SettingValues.reduceColor, text: "Minimal Mode")
        
        let button = UIButtonWithContext.init(type: .custom)
        button.imageView?.contentMode = UIView.ContentMode.scaleAspectFit
        button.setImage(UIImage(sfString: SFSymbol.chevronLeft, overrideString: "back")!.navIcon(), for: UIControl.State.normal)
        button.frame = CGRect.init(x: 0, y: 0, width: 30, height: 44)
        button.addTarget(self, action: #selector(handleBackButton), for: .touchUpInside)
        
        let barButton = UIBarButtonItem.init(customView: button)
        
        navigationItem.leftBarButtonItem = barButton

        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    @objc public func handleBackButton() {
        self.navigationController?.popViewController(animated: true)
    }
    
    var themeText: String?

    @objc func switchIsChanged(_ changed: UISwitch) {
        if changed == tintOutsideSwitch {
            SettingValues.onlyTintOutside = changed.isOn
            UserDefaults.standard.set(changed.isOn, forKey: SettingValues.pref_onlyTintOutside)
        } else if changed == reduceColor {
            SettingValues.reduceColor = changed.isOn
            UserDefaults.standard.set(changed.isOn, forKey: SettingValues.pref_reduceColor)
            setupBaseBarColors()
            let button = UIButtonWithContext.init(type: .custom)
            button.imageView?.contentMode = UIView.ContentMode.scaleAspectFit
            button.setImage(UIImage(sfString: SFSymbol.chevronLeft, overrideString: "back")!.navIcon(), for: UIControl.State.normal)
            button.frame = CGRect.init(x: 0, y: 0, width: 30, height: 44)
            button.addTarget(self, action: #selector(handleBackButton), for: .touchUpInside)
            
            let barButton = UIBarButtonItem.init(customView: button)
            
            navigationItem.leftBarButtonItem = barButton
            
            NotificationCenter.default.post(name: .reduceColorChanged, object: nil)
        } else if changed == nightEnabled {
            SettingValues.nightModeEnabled = changed.isOn
            UserDefaults.standard.set(changed.isOn, forKey: SettingValues.pref_nightMode)
            _ = ColorUtil.doInit()
            SingleSubredditViewController.cellVersion += 1

            self.tochange!.doCells()
            self.tochange!.tableView.reloadData()
        }
        self.setupViews()
        if SettingValues.reduceColor {
            self.primary.isUserInteractionEnabled = false
            self.primary.textLabel?.isEnabled = false
            self.primary.detailTextLabel?.isEnabled = false
            
            self.primary.detailTextLabel?.textColor = UIColor.fontColor
            self.primary.detailTextLabel?.numberOfLines = 0
            self.primary.detailTextLabel?.text = "Requires 'Reduce app colors' to be disabled"
        } else {
            self.primary.isUserInteractionEnabled = true
            self.primary.textLabel?.isEnabled = true
            self.primary.detailTextLabel?.isEnabled = true
            
            self.primary.detailTextLabel?.textColor = UIColor.fontColor
            self.primary.detailTextLabel?.numberOfLines = 0
            self.primary.detailTextLabel?.text = ""
        }
        self.setupBaseBarColors()
        self.tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0: return self.primary
            case 1: return self.accent
            case 2: return self.reduceColorCell
            default: fatalError("Unknown row in section 0")
            }
        case 1:
            switch indexPath.row {
            case 0: return self.night
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "theme") as! ThemeCellView
                cell.isUserInteractionEnabled = true
                cell.contentView.alpha = 1
                cell.setTheme(theme: ColorUtil.getNightTheme())
                return cell
            }
        case 2:
            switch indexPath.row {
            case 0: return self.custom
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "theme") as! ThemeCellView
                cell.setTheme(theme: customThemes[indexPath.row - 1])
                if ColorUtil.getDayTheme() == customThemes[indexPath.row - 1] {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
                if ColorUtil.shouldBeNight() {
                    cell.isUserInteractionEnabled = false
                    cell.contentView.alpha = 0.5
                } else {
                    cell.isUserInteractionEnabled = true
                    cell.contentView.alpha = 1
                }
                return cell
            }
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "theme") as! ThemeCellView
            cell.setTheme(theme: themes[indexPath.row])
            if ColorUtil.getDayTheme() == themes[indexPath.row] {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            if ColorUtil.shouldBeNight() {
                cell.isUserInteractionEnabled = false
                cell.contentView.alpha = 0.5
            } else {
                cell.isUserInteractionEnabled = true
                cell.contentView.alpha = 1
            }
            return cell
        default: fatalError("Unknown section")
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 2 && indexPath.row != 0
    }
    
    func selectTheme() {
        let chooseVC = SettingsThemeChooser()
        chooseVC.callback = { theme in
            SettingValues.nightTheme = theme.title
            UserDefaults.standard.set(theme.title, forKey: SettingValues.pref_nightTheme)
            UserDefaults.standard.synchronize()
            _ = ColorUtil.doInit()

            self.setupViews()
            self.tableView.reloadData()
            self.tochange!.doCells()
            self.tochange!.tableView.reloadData()
            self.setupBaseBarColors()
        }
        VCPresenter.presentModally(viewController: chooseVC, self)
    }
    
    var selectedTableView = UIView()

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedTableView = tableView.cellForRow(at: indexPath)!.contentView
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 0 {
            pickPrimary()
        } else if indexPath.section == 0 && indexPath.row == 1 {
            pickAccent()
        } else if indexPath.section == 1 && indexPath.row == 0 {
            if #available(iOS 13, *) {
            } else {
                self.selectTime()
            }
        } else if indexPath.section == 1 && indexPath.row == 1 {
            self.selectTheme()
        } else if indexPath.section == 2 && indexPath.row == 0 {
            if !VCPresenter.proDialogShown(feature: false, self) {
                let theme = SettingsCustomTheme()
                VCPresenter.presentAlert(UINavigationController(rootViewController: theme), parentVC: self)
            }
        } else if indexPath.section == 2 {
            if !VCPresenter.proDialogShown(feature: true, self) {
                let theme = customThemes[indexPath.row - 1]
                
                let themeView = ThemeCellView().then {
                    $0.setTheme(theme: theme)
                }
                let cv = themeView.contentView

                let alert = DragDownAlertMenu(title: theme.title, subtitle: "", icon: nil, extraView: cv, themeColor: nil, full: false)
                if ColorUtil.getCurrentTheme() != theme {
                    alert.addAction(title: "Apply Theme", icon: UIImage(sfString: .checkmark, overrideString: "add")?.navIcon()) {
                        UserDefaults.standard.set(theme.title, forKey: "theme")
                        UserDefaults.standard.synchronize()
                        
                        _ = ColorUtil.doInit()
                        SingleSubredditViewController.cellVersion += 1
                        self.tableView.reloadData()

                        self.setupViews()
                        self.tochange!.doCells()
                        self.tochange!.tableView.reloadData()
                        self.tableView.reloadData()
                        self.setupBaseBarColors()
                    }
                }
                
                alert.extraViewHeight = 60
                
                alert.addAction(title: "Edit Theme", icon: UIImage(sfString: .pencil, overrideString: "edit")?.navIcon()) {
                    let theme = SettingsCustomTheme()
                    theme.delegate = self
                    theme.inputTheme = self.customThemes[indexPath.row - 1].title
                    VCPresenter.presentAlert(UINavigationController(rootViewController: theme), parentVC: self)
                }

                alert.addAction(title: "Share Theme", icon: UIImage(sfString: .squareAndArrowUp, overrideString: "share")?.navIcon()) {
                    let inputTheme = self.customThemes[indexPath.row - 1].title
                    let textShare = UserDefaults.standard.string(forKey: "Theme+" + inputTheme) ?? UserDefaults.standard.string(forKey: "Theme+" + inputTheme.replacingOccurrences(of: "#", with: "<H>").addPercentEncoding) ?? UserDefaults.standard.string(forKey: "Theme+" + inputTheme.replacingOccurrences(of: "#", with: "<H>")) ?? ""

                    let activityViewController = UIActivityViewController(activityItems: [textShare], applicationActivities: nil)
                    if let presenter = activityViewController.popoverPresentationController {
                        presenter.sourceView = tableView.cellForRow(at: indexPath)
                        presenter.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? CGRect.zero
                    }
                    let window = UIApplication.shared.keyWindow!
                    if let modalVC = window.rootViewController?.presentedViewController {
                        modalVC.present(activityViewController, animated: true, completion: nil)
                    } else {
                        window.rootViewController!.present(activityViewController, animated: true, completion: nil)
                    }
                }

                if ColorUtil.getCurrentTheme() != theme {
                    alert.addAction(title: "Delete Theme", icon: UIImage(sfString: .trash, overrideString: "delete")?.navIcon()) {
                        let title = self.customThemes[indexPath.row - 1].title
                        UserDefaults.standard.removeObject(forKey: "Theme+" + title.addPercentEncoding)
                        UserDefaults.standard.synchronize()
                        self.customThemes = self.customThemes.filter({ $0.title != title })
                        ColorUtil.themes = ColorUtil.themes.filter({ $0.title != title })
                        self.tableView.reloadData()
                    }
                }

                alert.show(self)
            }
        } else if indexPath.section == 3 {
            let row = indexPath.row
            let theme = themes[row]
            UserDefaults.standard.set(theme.title, forKey: "theme")
            UserDefaults.standard.synchronize()
            _ = ColorUtil.doInit()
            SingleSubredditViewController.cellVersion += 1
            self.tableView.reloadData()

            self.setupViews()
            self.tochange!.doCells()
            self.tochange!.tableView.reloadData()
            self.tableView.reloadData()
            self.setupBaseBarColors()
        }
    }

    func getHourOffset(base: Int) -> Int {
        if base == 0 {
            return 12
        }
        return base
    }

    func getMinuteString(base: Int) -> String {
        return String.init(format: "%02d", arguments: [base])
    }

    func selectTime() {
        let alert = AlertController(title: "Select night hours", message: nil, preferredStyle: .alert)

        let cancelActionButton = AlertAction(title: "Save", style: .preferred) { _ -> Void in
            _ = ColorUtil.doInit()
            self.setupViews()
            SingleSubredditViewController.cellVersion += 1

            self.tableView.reloadData()
            self.tochange!.doCells()
            self.tochange!.tableView.reloadData()
            self.setupBaseBarColors()
        }
        alert.addAction(cancelActionButton)

        var values: [[String]] = [[], [], [], [], [], []]
        for i in 0...11 {
            values[0].append("\(getHourOffset(base: i))")
            values[3].append("\(getHourOffset(base: i))")
        }
        for i in 0...59 {
            if i % 5 == 0 {
                values[1].append(getMinuteString(base: i))
                values[4].append(getMinuteString(base: i))
            }
        }
        values[2].append("PM")
        values[5].append("AM")

        var initialSelection: [PickerViewViewController.Index] = []
        initialSelection.append((0, SettingValues.nightStart))
        initialSelection.append((1, SettingValues.nightStartMin / 5))
        initialSelection.append((3, SettingValues.nightEnd))
        initialSelection.append((4, SettingValues.nightEndMin / 5))
        alert.setupTheme()
        
        alert.attributedTitle = NSAttributedString(string: "Select night hours", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 17), NSAttributedString.Key.foregroundColor: UIColor.fontColor])
        
        let pickerView = PickerViewViewControllerColored(values: values, initialSelection: initialSelection, action: { _, _, index, _ in
            switch index.column {
            case 0:
                SettingValues.nightStart = index.row
                UserDefaults.standard.set(SettingValues.nightStart, forKey: SettingValues.pref_nightStartH)
                UserDefaults.standard.synchronize()
            case 1:
                SettingValues.nightStartMin = index.row * 5
                UserDefaults.standard.set(SettingValues.nightStartMin, forKey: SettingValues.pref_nightStartM)
                UserDefaults.standard.synchronize()
            case 3:
                SettingValues.nightEnd = index.row
                UserDefaults.standard.set(SettingValues.nightEnd, forKey: SettingValues.pref_nightEndH)
                UserDefaults.standard.synchronize()
            case 4:
                SettingValues.nightEndMin = index.row * 5
                UserDefaults.standard.set(SettingValues.nightEndMin, forKey: SettingValues.pref_nightEndM)
                UserDefaults.standard.synchronize()
            default: break
            }
        })
        
        alert.addChild(pickerView)

        let pv = pickerView.view!
        alert.contentView.addSubview(pv)
        
        pv.edgeAnchors /==/ alert.contentView.edgeAnchors - 14
        pv.heightAnchor /==/ CGFloat(216)
        pickerView.didMove(toParent: alert)
        
        alert.addCancelButton()
        alert.addBlurView()
        
        self.present(alert, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3
        case 1: return 2
        case 2: return customThemes.count + 1
        case 3: return themes.count
        default: fatalError("Unknown number of sections")
        }
    }

    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */

}
final public class PickerViewViewControllerColored: UIViewController {
    
    public typealias Values = [[String]]
    public typealias Index = (column: Int, row: Int)
    public typealias Action = (_ vc: UIViewController, _ picker: UIPickerView, _ index: Index, _ values: Values) -> Void
    
    fileprivate var action: Action?
    fileprivate var values: Values = [[]]
    fileprivate var initialSelection: [Index]?
    
    fileprivate lazy var pickerView: UIPickerView = {
        return $0
    }(UIPickerView())
    
    public init(values: Values, initialSelection: [Index]? = nil, action: Action?) {
        super.init(nibName: nil, bundle: nil)
        self.values = values
        self.initialSelection = initialSelection
        self.action = action
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        Log("has deinitialized")
    }
    
    override public func loadView() {
        view = pickerView
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        pickerView.dataSource = self
        pickerView.delegate = self
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        if let initialSelection = initialSelection {
            for index in initialSelection {
                if values.count > index.column && values[index.column].count > index.row {
                    pickerView.selectRow(index.row, inComponent: index.column, animated: true)
                }
            }
        }
    }
}

extension SettingsTheme: SettingsCustomThemeDelegate {
    func themeSaved() {
        _ = ColorUtil.doInit()
        SingleSubredditViewController.cellVersion += 1
        self.tableView.reloadData()
        
        self.setupViews()
        self.tochange!.doCells()
        self.tochange!.tableView.reloadData()
        self.tableView.reloadData()
        self.setupBaseBarColors()

        self.redoThemes()
    }
}

extension PickerViewViewControllerColored: UIPickerViewDataSource, UIPickerViewDelegate {
    
    // returns the number of 'columns' to display.
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return values.count
    }
    
    // returns the # of rows in each component..
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return values[component].count
    }
    
    // these methods return either a plain NSString, a NSAttributedString, or a view (e.g UILabel) to display the row for the component.
    // for the view versions, we cache any hidden and thus unused views and pass them back for reuse.
    // If you return back a different object, the old one will be released. the view will be centered in the row rect
    public func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return NSAttributedString(string: values[component][row], attributes: [NSAttributedString.Key.foregroundColor: UIColor.fontColor, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 8)])
    }
    /*
     public func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
     // attributed title is favored if both methods are implemented
     }
     
     
     public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
     
     }
     */
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        action?(self, pickerView, Index(column: component, row: row), values)
    }
}

@available(iOS 14.0, *)
extension SettingsTheme: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        if isAccent {
            accentChosen = viewController.selectedColor
            titleLabel.textColor = viewController.selectedColor
            self.accent.imageView?.image = UIImage(named: "circle")?.toolbarIcon().getCopy(withColor: accentChosen!)
            reduceColor.onTintColor = accentChosen!

            UserDefaults.standard.setColor(color: self.accentChosen!, forKey: "accentcolor")
            ColorUtil.baseAccent = viewController.selectedColor
            
            tochange?.tableView.reloadData()
            nightEnabled.onTintColor = ColorUtil.baseAccent
        } else {
            primaryChosen = viewController.selectedColor
            self.primary.imageView?.image = UIImage(named: "circle")?.toolbarIcon().getCopy(withColor: primaryChosen!)
            UserDefaults.standard.setColor(color: viewController.selectedColor, forKey: "basecolor")
            ColorUtil.baseColor = viewController.selectedColor
        }
        
        UserDefaults.standard.synchronize()
        self.tableView.reloadData()
    }
}
