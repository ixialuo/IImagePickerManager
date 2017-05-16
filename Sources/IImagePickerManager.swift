//
//  IImagePickerManager.swift
//  IImagePickerManager
//
//  Created by XiaLuo on 2017/5/16.
//  Copyright © 2017年 Hangzhou Gravity Cyber Info Corp. All rights reserved.
//

import UIKit
import TOCropViewController
import CTAssetsPickerController

//MARK: - 图片编辑类型
public enum IImagePickerEditingStyle {
    case none
    case system
    case custom
}

//MARK: - 图片选择类型
public enum ImagePickerSelectedStyle {
    case single
    case multiple
}

//MARK: - TOCropViewController属性设置
public struct TOCropViewControllerStyle {
    public var croppingStyle = TOCropViewCroppingStyle.default
    public var customAspectRatio = CGSize.zero
    public var aspectRatioLockEnabled: Bool = false
    public var resetAspectRatioEnabled: Bool = true
    public var rotateButtonsHidden: Bool = false
}

//MARK: - CTAssetsPickerController属性设置
public struct CTAssetsPickerControllerStyle {
    public var defaultAssetCollection = PHAssetCollectionSubtype.smartAlbumUserLibrary
    public var showsEmptyAlbums: Bool = true
    public var showsSelectionIndex: Bool = true
    public var shouldSelctedNum: Int = 9
}


//MARK: - IImagePickerManger
open class IImagePickerManager: NSObject {
    
    open static let shared = IImagePickerManager()
    open weak var delegate: IImagePickerMangerDelegate?
    
    open var editingStyle = IImagePickerEditingStyle.none
    open var selectedStyle = ImagePickerSelectedStyle.single
    
    open var toCropViewControllerStyle = TOCropViewControllerStyle()
    open var ctAssetsPickerControllerStyle = CTAssetsPickerControllerStyle()
    
    fileprivate var viewController = UIViewController()
    
    open func showImageActionSheet(invoker: UIViewController) {
        
        viewController = invoker
        let alertVc = UIAlertController(title: nil, message: "选择照片", preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        alertVc.addAction(cancelAction)
        let takePhotoAction = UIAlertAction(title: "照相", style: .default) { (action) in
            self.showCamera(invoker: invoker)
        }
        alertVc.addAction(takePhotoAction)
        let photoAction = UIAlertAction(title: "相册", style: .default) { (action) in
            self.showPhoto(invoker: invoker)
        }
        alertVc.addAction(photoAction)
        invoker.present(alertVc, animated: true, completion: nil)
    }
    
    //MARK: - 相机
    private func showCamera(invoker: UIViewController) {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.allowsEditing = editingStyle == .system
            invoker.present(picker, animated: true, completion: nil)
        }
    }
    
    //MARK: - 图片
    private func showPhoto(invoker: UIViewController) {
        
        switch selectedStyle {
        case .single:
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = .photoLibrary
                picker.allowsEditing = editingStyle == .system
                invoker.present(picker, animated: true, completion: nil)
            }
            
        case .multiple:
            PHPhotoLibrary.requestAuthorization { (status) in
                DispatchQueue.main.async(execute: {
                    let assetsPicker = CTAssetsPickerController()
                    assetsPicker.delegate = self
                    assetsPicker.showsEmptyAlbums = self.ctAssetsPickerControllerStyle.showsEmptyAlbums
                    assetsPicker.showsSelectionIndex = self.ctAssetsPickerControllerStyle.showsSelectionIndex
                    assetsPicker.defaultAssetCollection = self.ctAssetsPickerControllerStyle.defaultAssetCollection
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
                    assetsPicker.assetsFetchOptions = fetchOptions
                    if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
                        assetsPicker.modalPresentationStyle = UIModalPresentationStyle.formSheet
                    }
                    invoker.present(assetsPicker, animated: true, completion: nil)
                })
            }
        }
    }
}


//MARK: - IImagePickerMangerDelegate
@objc public protocol IImagePickerMangerDelegate: NSObjectProtocol {
    func cropViewController(picker: UIViewController, images: [UIImage], thumImages: [UIImage]?)
}


//MARK: - UINavigationControllerDelegate, UIImagePickerControllerDelegate
extension IImagePickerManager: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        switch editingStyle {
        case .none:
            picker.dismiss(animated: true) {
                if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
                    self.delegate?.cropViewController(picker: picker, images: [image], thumImages: nil)
                }
            }
            
        case .system:
            picker.dismiss(animated: true) {
                if let image = info[UIImagePickerControllerEditedImage] as? UIImage {
                    self.delegate?.cropViewController(picker: picker, images: [image], thumImages: nil)
                }
            }
            
        case .custom:
            if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
                showCropViewController(invoker: picker, image: image)
            }
        }
    }
    
    fileprivate func showCropViewController(invoker: UIViewController, image: UIImage) {
        
        let cropVC = TOCropViewController(croppingStyle: toCropViewControllerStyle.croppingStyle, image: image)
        cropVC.delegate = self
        switch toCropViewControllerStyle.croppingStyle {
        case .default:
            cropVC.customAspectRatio = toCropViewControllerStyle.customAspectRatio
            cropVC.aspectRatioLockEnabled = toCropViewControllerStyle.aspectRatioLockEnabled
            cropVC.resetAspectRatioEnabled = toCropViewControllerStyle.resetAspectRatioEnabled
            cropVC.rotateButtonsHidden = toCropViewControllerStyle.rotateButtonsHidden
            
        case .circular:
            break
        }
        
        cropVC.toolbar.doneTextButton.setTitleColor(UIColor.white, for: .normal)
        cropVC.toolbar.cancelTextButton.setTitleColor(UIColor.white, for: .normal)
        
        if let imagePicker = invoker as? UIImagePickerController {
            imagePicker.pushViewController(cropVC, animated: true)
        }else {
            invoker.present(cropVC, animated: true, completion: nil)
        }
        
    }
}


//MARK: - TOCropViewControllerDelegate
extension IImagePickerManager: TOCropViewControllerDelegate {
    
    public func cropViewController(_ cropViewController: TOCropViewController, didCropToImage image: UIImage, rect cropRect: CGRect, angle: Int) {
        cropViewController.dismiss(animated: true) {
            self.delegate?.cropViewController(picker: cropViewController, images: [image], thumImages: nil)
        }
    }
    
    public func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
        cropViewController.dismiss(animated: true, completion: nil)
    }
    
}


//MARK: - CTAssetsPickerControllerDelegate
extension IImagePickerManager: CTAssetsPickerControllerDelegate {
    
    public func assetsPickerController(_ picker: CTAssetsPickerController!, didFinishPickingAssets assets: [Any]!) {
        
        var images = [UIImage]()
        if let phAssets = assets as? [PHAsset] {
            for phAsset in phAssets {
                let screen = UIScreen.main
                let scale = screen.scale
                let size = CGSize(width: screen.bounds.width*scale, height: screen.bounds.height*scale)
                let options = PHImageRequestOptions()
                options.resizeMode = PHImageRequestOptionsResizeMode.exact
                options.isNetworkAccessAllowed = true
                options.deliveryMode = PHImageRequestOptionsDeliveryMode.highQualityFormat
                options.version = PHImageRequestOptionsVersion.current
                options.isSynchronous = true
                PHImageManager.default().requestImage(for: phAsset, targetSize: size, contentMode: .aspectFit, options: options, resultHandler: { (image, info) in
                    if let aImage = image {
                        images.append(aImage)
                    }
                })
            }
        }
        
        switch editingStyle {
        case .none:
            picker.dismiss(animated: true, completion: {
                self.delegate?.cropViewController(picker: picker, images: images, thumImages: nil)
            })
            
        case .system,  .custom:
            
            if images.count == 1 {
                picker.dismiss(animated: false, completion: {
                    self.showCropViewController(invoker: self.viewController, image: images[0])
                })
                
            }else {
                picker.dismiss(animated: true, completion: {
                    self.delegate?.cropViewController(picker: picker, images: images, thumImages: nil)
                })
            }
        }
    }
    
    public func assetsPickerController(_ picker: CTAssetsPickerController!, shouldSelect asset: PHAsset!) -> Bool {
        if picker.selectedAssets.count >= ctAssetsPickerControllerStyle.shouldSelctedNum {
            
        }
        return  picker.selectedAssets.count < ctAssetsPickerControllerStyle.shouldSelctedNum
    }
}


