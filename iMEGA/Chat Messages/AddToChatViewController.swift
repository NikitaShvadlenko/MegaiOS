
import UIKit

class AddToChatViewController: UIViewController {
    
    // MARK:- Properties.

    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var contentViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var topCollectionView: UICollectionView!
    @IBOutlet weak var middleCollectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    var dismissHandler: ((AddToChatViewController) -> Void)?
    var presentAndDismissAnimationDuration: TimeInterval = 0.4
    
    // MARK:- View lifecycle methods.

    override func viewDidLoad() {
        super.viewDidLoad()

        topCollectionView.register(AddToChatCameraCollectionCell.nib,
                                   forCellWithReuseIdentifier: AddToChatCameraCollectionCell.reuseIdentifier)
        topCollectionView.dataSource = self
        topCollectionView.delegate = self
    }
    
    // MARK:- Actions.

    @IBAction func backgroundViewTapped(_ tapGesture: UITapGestureRecognizer) {
        guard let handler = dismissHandler else {
            return
        }
        
        dismissAnimation { _ in
            handler(self)
        }
    }
    
    // MARK:- Animation methods while presenting and dismissing.
    
    func presentAnimation() {
        contentViewBottomConstraint.constant = -contentViewHeightConstraint.constant
        view.layoutIfNeeded()

        UIView.animate(withDuration: presentAndDismissAnimationDuration) {
            self.contentViewBottomConstraint.constant = 0.0
            self.view.layoutIfNeeded()
        }
    }

    func dismissAnimation(completion: ((Bool) -> Void)?) {
        UIView.animate(withDuration: presentAndDismissAnimationDuration,
                       animations: {
                        self.contentViewBottomConstraint.constant = -self.contentViewHeightConstraint.constant
                        self.view.layoutIfNeeded()
        }, completion: completion)
    }
}

extension AddToChatViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddToChatCameraCollectionCell.reuseIdentifier,
                                                      for: indexPath) as! AddToChatCameraCollectionCell
        return cell
    }
    
    
}

extension AddToChatViewController: UICollectionViewDelegate {
    
}

