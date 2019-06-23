//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var captureSessionManager: TTPhotoProtocol?
    @IBOutlet private weak var previewView: PreviewView!

    override func viewDidLoad() {
        super.viewDidLoad()
        captureSessionManager?.weaklayer = self.previewView.videoPreviewLayer
        captureSessionManager?.start()
    }
    
    @IBAction func capturePhoto(_ sender: Any) {
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation
        captureSessionManager?.capturePhoto(orientation: videoPreviewLayerOrientation!)
    }
    
    @IBAction func changwCamera(_ sender: Any) {
        captureSessionManager?.changeCamera()
    }
    
    internal override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let viewController: AlbumsTableViewController = segue.destination as! AlbumsTableViewController
        viewController.captureSessionManager = self.captureSessionManager
    }
    
}

