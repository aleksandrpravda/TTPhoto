//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import UIKit
import Photos

class AlbumsTableViewController: UITableViewController {
    
    var albums: [PHAssetCollection]?
    var captureSessionManager: TTPhotoLibraryProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        albums = captureSessionManager?.getCollections()
        self.tableView.reloadData()
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albums?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumsTableViewCellIdentifire", for: indexPath) as! AlbumsTableViewCell

        cell.title.text = albums?[indexPath.row].localizedTitle
        return cell
    }
    
    internal override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let viewController: LibraryViewController = segue.destination as! LibraryViewController
        viewController.captureSessionManager = self.captureSessionManager
        viewController.collection = albums?[tableView.indexPathForSelectedRow!.row]
    }
}
