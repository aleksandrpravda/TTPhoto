//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import UIKit

class CollectionImageCellCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    var identifire: String = ""
    @IBOutlet weak var addButton: UIButton!
    private var isChecked = false
    var isCheckedProperty: Bool {
        get{ return isChecked }
        set {
            isChecked = newValue
            if isChecked {
                addButton.setTitle("✓", for: .normal)
                addButton.setTitleColor(.green, for: .normal)
            } else {
                addButton.setTitle("O", for: .normal)
                addButton.setTitleColor(.red, for: .normal)
            }
        }
    }
    var selectionButtonHandler: (Bool, String) -> Bool = {_,_  in return false}
    
    @IBAction func onAddRemove(_ sender: UIButton) {
        self.isCheckedProperty = self.selectionButtonHandler(!isChecked, identifire)
    }
}
