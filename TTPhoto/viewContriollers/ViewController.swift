//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var captureSessionManager: TTPhotoProtocol?
    @IBOutlet private weak var previewView: PreviewView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.captureSessionManager?.weaklayer = self.previewView.videoPreviewLayer
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.captureSessionManager?.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSessionManager?.stop()
    }
    
    @IBAction func capturePhoto(_ sender: Any) {
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation
        self.captureSessionManager?.capturePhoto(orientation: videoPreviewLayerOrientation!)
    }
    
    @IBAction func changwCamera(_ sender: Any) {
        self.captureSessionManager?.changeCamera()
    }
    
    internal override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let viewController: AlbumsTableViewController = segue.destination as! AlbumsTableViewController
        viewController.captureSessionManager = self.captureSessionManager
    }
    
}

