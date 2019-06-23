//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import UIKit
import Photos
import Social

class LibraryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIActionSheetDelegate {
    @IBOutlet weak var postBtn: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!
    var captureSessionManager: TTPhotoLibraryProtocol?
    var collection: PHAssetCollection?
    var identifiresToPost = [String]()
    let maxAllowedImagesToAdd = 10
    
    var assets: [PHAsset]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.postBtn.isEnabled = false
        self.assets = captureSessionManager?.fetchAssetFromCollection(from: self.collection)
        self.collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assets?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectioViewCellReuseIdentifire", for: indexPath as IndexPath) as! CollectionImageCellCollectionViewCell
        if let asset = assets?[indexPath.row] {
            cell.identifire = asset.localIdentifier
            cell.isCheckedProperty = self.identifiresToPost.contains(cell.identifire)
            cell.selectionButtonHandler = { isEnabled, identifire in
                if self.identifiresToPost.count >= self.maxAllowedImagesToAdd {
                    return false
                }
                if (isEnabled) {
                    if !self.identifiresToPost.contains(identifire) {
                        self.identifiresToPost.append(identifire)
                    }
                } else {
                    if let index = self.identifiresToPost.firstIndex(of: identifire) {
                        self.identifiresToPost.remove(at: index)
                    }
                }
                self.postBtn.isEnabled = !self.identifiresToPost.isEmpty
                return isEnabled
            }
            self.captureSessionManager?.fetchImage(asset: asset, size: CGSize(width: 100, height: 100), callback: { image in
                if cell.identifire == asset.localIdentifier {
                    cell.imageView.image = image
                }
            })
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = self.collectionView.frame.size.width / 3 - 20
        return CGSize(width: width, height: width)
    }
    
    @IBAction func post(_ sender: Any) {
        self.getImagesToPost(callback: { images in
            _ = images.map { image in
                if let vc = SLComposeViewController(forServiceType: SLServiceTypeFacebook) {
                    vc.setInitialText("Hello")
                    vc.add(image)
                    vc.completionHandler = { result in
                        switch(result) {
                        case .cancelled:
                            break;
                        case .done:
                            self.postBtn.isEnabled = false
                            self.identifiresToPost.removeAll()
                            self.collectionView.reloadData()
                            break;
                        @unknown default:
                            break
                        }
                    };
                    self.present(vc, animated: true)
                }
            }
        })
    }
    
    func getImagesToPost(callback: @escaping ([UIImage]) -> Void) {
        let assets = self.captureSessionManager?.fetchAsset(with: self.identifiresToPost)
        if  let a = assets {
            for asset in a {
                var counter = 0
                var images = [UIImage]()
                self.captureSessionManager?.fetchImage(asset: asset, size: PHImageManagerMaximumSize, callback: { image in
                    if let image = image {
                        images.append(image)
                    }
                    counter += 1
                    if counter >= self.identifiresToPost.count {
                        callback(images)
                    }
                })
            }
        }
    }
}
