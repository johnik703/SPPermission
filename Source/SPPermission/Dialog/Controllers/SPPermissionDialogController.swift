// The MIT License (MIT)
// Copyright © 2017 Ivan Vorobei (hello@ivanvorobei.by)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

public class SPPermissionDialogController: UIViewController {
    
    weak var delegate: SPPermissionDialogDelegate?
    weak var dataSource: SPPermissionDialogDataSource?
    var permissions: [SPPermissionType]
    var closeButton = SPPermissionCloseButton()
    var areaView = SPPermissionDialogView()
    var bottomLabel = UILabel()
    var backgroundView = SPPermissionGradeBlurView()
    
    private var isHiddenStatusBar: Bool? = nil {
        didSet {
            SPPermissionStyle.Animation.base(0.3, animations: {
                self.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    public override var prefersStatusBarHidden: Bool {
        return self.isHiddenStatusBar ?? super.prefersStatusBarHidden
    }
    
    private var barStyle: UIStatusBarStyle? = nil
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.barStyle ?? super.preferredStatusBarStyle
    }
    
    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    init(permissions: [SPPermissionType]) {
        self.permissions = permissions
        super.init(nibName: nil, bundle: nil)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.backgroundView.setGradeAlpha(0, blurRaius: 0)
        self.view.addSubview(self.backgroundView)
        
        self.closeButton.backgroundColor = SPPermissionStyle.Colors.white
        self.closeButton.widthIconFactor = 0.36
        self.closeButton.heightIconFactor = 0.36
        self.closeButton.alpha = 0
        self.closeButton.addTarget(self, action: #selector(self.tapClose), for: .touchUpInside)
        self.view.addSubview(self.closeButton)
        
        self.bottomLabel.text = (self.dataSource?.bottomComment ?? "")
        self.bottomLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        self.bottomLabel.textColor = SPPermissionStyle.Colors.white
        self.bottomLabel.numberOfLines = 0
        self.bottomLabel.textAlignment = .center
        self.bottomLabel.alpha = 0
        self.view.addSubview(self.bottomLabel)
        
        self.areaView.subtitleLabel.text = (self.dataSource?.dialogSubtitle ?? "Permissions Request").uppercased()
        self.areaView.titleLabel.text = (self.dataSource?.dialogTitle ?? "Need Permissions")
        for permission in self.permissions {
            let view = SPPermissionDialogLineView.init(
                permission: permission,
                title: (self.dataSource?.name?(for: permission) ?? permission.name),
                subtitle: (self.dataSource?.description?(for: permission) ?? self.description(for: permission)),
                allowTitle: self.dataSource?.allowTitle ?? "Allow",
                allowedTitle: self.dataSource?.allowedTitle ?? "Allowed",
                image: self.dataSource?.image?(for: permission)
            )
            view.button.addTarget(self, action: #selector(self.request(with:)), for: .touchUpInside)
            self.areaView.add(view: view)
        }
        self.areaView.descriptionLabel.text = (self.dataSource?.dialogComment ?? "Permissions are necessary for the correct work of the application and the performance of all functions. Push are not required permissions")
        self.view.addSubview(self.areaView)
        self.areaView.layer.anchorPoint = CGPoint.init(x: 0.5, y: 0.5)
        
        let panGesture = UIPanGestureRecognizer.init(target: self, action: #selector(self.handleGesture(sender:)))
        panGesture.maximumNumberOfTouches = 1
        self.areaView.addGestureRecognizer(panGesture)
        self.animator = UIDynamicAnimator(referenceView: self.view)
        
        self.updateLayout(with: self.view.frame.size)
    }
    
    @objc func request(with button: UIButton) {
        var permission: SPPermissionType?
        var permissionView: SPPermissionDialogLineView?
        
        for view in self.areaView.views {
            if view.button == button {
                permission = view.permission
                permissionView = view
                break
            }
        }
        
        if let permission = permission {
            SPPermission.request(permission, with: {
                if SPPermission.isAllow(permission) {
                    self.delegate?.didAllow?(permission: permission)
                    permissionView?.updateStyle()
                    for permission in self.permissions {
                        if SPPermission.isAllow(permission) {
                            if self.permissions.last == permission {
                                SPPermissionStyle.Delay.wait(0.2, closure: {
                                    self.hide(withDialog: true)
                                })
                            }
                        } else {
                            return
                        }
                    }
                }
            })
        }
    }
    
    func present(on viewController: UIViewController) {
        self.animator.removeAllBehaviors()
        self.areaView.alpha = 0
        self.closeButton.alpha = 0
        self.bottomLabel.alpha = 0
        self.areaView.transform = .identity
        self.barStyle = viewController.preferredStatusBarStyle
        self.modalPresentationStyle = .overCurrentContext
        self.modalPresentationCapturesStatusBarAppearance = true
        viewController.present(self, animated: false, completion: {
            self.isHiddenStatusBar = true
            self.areaView.center = CGPoint.init(
                x: self.view.center.x,
                y: self.view.center.y * 1.2
            )
            SPPermissionStyle.Animation.base(0.8, animations: {
                self.backgroundView.setGradeAlpha(0.07, blurRaius: 4)
            })
            SPPermissionStyle.Delay.wait(0.21, closure: {
                self.snapBehavior = UISnapBehavior(item: self.areaView, snapTo: self.areaCenter)
                self.animator.addBehavior(self.snapBehavior)
                SPPermissionStyle.Animation.base(0.3, animations: {
                    self.areaView.alpha = 1
                })
                SPPermissionStyle.Delay.wait(0.2, closure: {
                    SPPermissionStyle.Animation.base(0.3, animations: {
                        self.bottomLabel.alpha = 1
                        if self.dataSource?.showCloseButton ?? false {
                            self.closeButton.alpha = 1
                        }
                    })
                })
            })
        })
    }
    
    @objc func tapClose() {
        self.hide(withDialog: true)
    }
    
    func hide(withDialog: Bool) {
        SPPermissionStyle.Delay.wait(0.2, closure: {
            self.isHiddenStatusBar = false
        })
        if withDialog {
            SPPermissionStyle.Animation.spring(0.4, animations: {
                    self.animator.removeAllBehaviors()
                    self.areaView.transform = CGAffineTransform.init(scaleX: 0.9, y: 0.9)
                    self.areaView.alpha = 0
            },
                options: [.curveEaseIn, .beginFromCurrentState],
                withComplection: {})
        }
        SPPermissionStyle.Animation.base(0.3, animations: {
            self.bottomLabel.alpha = 0
            self.closeButton.alpha = 0
        })
        SPPermissionStyle.Animation.base(0.6, animations: {
            self.backgroundView.setGradeAlpha(0, blurRaius: 0)
        }, withComplection: {
            self.dismiss(animated: false, completion: {
                self.animator.removeAllBehaviors()
                self.areaView.transform = .identity
                self.delegate?.didHide?()
            })
        })
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (contex) in
            self.updateLayout(with: size)
        }, completion: nil)
    }
    
    private func updateLayout(with size: CGSize) {
        animator.removeAllBehaviors()
        
        self.closeButton.frame = CGRect.init(x: 0, y: 0, width: 35, height: 35)
        self.closeButton.frame.origin.x = size.width - 27 - self.closeButton.frame.width
        self.closeButton.frame.origin.y = 23
        self.closeButton.layer.cornerRadius = self.closeButton.frame.height / 2
        let shadowPath = UIBezierPath.init(
            roundedRect: CGRect.init(x: 0, y: 9, width: self.closeButton.frame.width, height: self.closeButton.frame.height),
            cornerRadius: self.closeButton.layer.cornerRadius
        )
        self.closeButton.layer.shadowColor = UIColor.black.cgColor
        self.closeButton.layer.shadowOffset = CGSize.zero
        self.closeButton.layer.shadowOpacity = Float(0.07)
        self.closeButton.layer.shadowRadius = 17
        self.closeButton.layer.masksToBounds = false
        self.closeButton.layer.shadowPath = shadowPath.cgPath
        
        self.backgroundView.frame = CGRect.init(origin: .zero, size: size)
        var areaViewWidth = size.width - 20 * 2
        if areaViewWidth > 380 {
            areaViewWidth = 380
        }
        self.areaView.layoutWidth = areaViewWidth
        self.areaView.frame = CGRect.init(origin: self.areaView.frame.origin, size: CGSize.init(width: self.areaView.frame.width, height: self.areaView.layoutHeight))
        self.areaView.center = self.areaCenter
        
        var bottomLabelWidth: CGFloat = size.width * 0.4
        if bottomLabelWidth > 230 {
            bottomLabelWidth = 230
        }
        self.bottomLabel.sizeToFit()
        self.bottomLabel.frame = CGRect.init(origin: self.bottomLabel.frame.origin, size: CGSize.init(width: bottomLabelWidth, height: self.bottomLabel.frame.height))
        self.bottomLabel.center.x = size.width / 2
        if #available(iOS 11.0, *) {
            self.bottomLabel.frame.origin.y = size.height - self.view.safeAreaInsets.bottom - 30 - self.bottomLabel.frame.height
        } else {
             self.bottomLabel.frame.origin.y = size.height - 30 - self.bottomLabel.frame.height
        }
        SPPermissionStyle.Shadow.setShadowOffsetForLabel(self.bottomLabel, blurRadius: 3, widthOffset: 0, heightOffset: 0, opacity: 0.18)
        
        let bottomLabelAlpha: CGFloat = SPPermissionStyle.Orientation.isPortrait ? 1 : 0
        if self.areaView.alpha == 1 {
            SPPermissionStyle.Animation.base(0.22, animations: {
                self.bottomLabel.alpha = bottomLabelAlpha
            })
        }
    }
    
    private var areaCenter: CGPoint {
        return CGPoint(x: self.view.center.x, y: self.view.center.y)
    }
    
    //MARK: - animator
    var animator = UIDynamicAnimator()
    var attachmentBehavior : UIAttachmentBehavior!
    var gravityBehaviour : UIGravityBehavior!
    var snapBehavior : UISnapBehavior!
    
    //MARK: - handle gesture
    @objc func handleGesture(sender: AnyObject) {
        let myView = self.areaView
        let location = sender.location(in: view)
        let boxLocation = sender.location(in: myView)
        
        if sender.state == UIGestureRecognizer.State.began {
            animator.removeAllBehaviors()
            let centerOffset = UIOffset(horizontal: boxLocation.x - myView.bounds.midX, vertical: boxLocation.y - myView.bounds.midY);
            attachmentBehavior = UIAttachmentBehavior(item: myView, offsetFromCenter: centerOffset, attachedToAnchor: location)
            attachmentBehavior.frequency = 0
            animator.addBehavior(attachmentBehavior)
        }
        else if sender.state == UIGestureRecognizer.State.changed {
            self.attachmentBehavior.anchorPoint = location
        }
        else if sender.state == UIGestureRecognizer.State.ended {
            self.animator.removeBehavior(attachmentBehavior)
            self.snapBehavior = UISnapBehavior(item: myView, snapTo: self.areaCenter)
            self.animator.addBehavior(snapBehavior)
            let translation = sender.translation(in: view)
            if translation.y > 100 {
                animator.removeAllBehaviors()
                gravityBehaviour = UIGravityBehavior(items: [areaView])
                gravityBehaviour.gravityDirection = CGVector.init(dx: 0, dy: 10)
                animator.addBehavior(gravityBehaviour)
                self.hide(withDialog: false)
            }
        }
    }
    
    //MARK: - other
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SPPermissionDialogController {
    
    fileprivate func description(for permission: SPPermissionType) -> String {
        switch permission {
        case .camera:
            return "Allow app for use camera"
        case .calendar:
            return "Application can add events to calendar"
        case .contacts:
            return "Access for your contacts and phones"
        case .microphone:
            return "Allow record voice from app"
        case .notification:
            return "Get important information without opening app."
        case .photoLibrary:
            return "Access for save photos in your gallery"
        case .reminders:
            return "Application can create new task"
        case .speech:
            return "Allow check you voice"
        case .locationAlways:
            return "App will can check your location"
        case .locationWhenInUse:
            return "App will can check your location"
        case .locationWithBackground:
            return "App will can check your location"
        case .mediaLibrary:
            return "Allow check your media"
        }
    }
}
