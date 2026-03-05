import numpy as np
from filterpy.kalman import KalmanFilter

# SORT Algorithm Components
# Simplified Implementation for High-Frequency Bounding Box Tracking

def linear_assignment(cost_matrix):
    try:
        import scipy.optimize as linear_assignment
        x, y = linear_assignment.linear_sum_assignment(cost_matrix)
        return np.array(list(zip(x, y)))
    except ImportError:
        # Fallback if scipy not installed
        from scipy.optimize import linear_sum_assignment
        x, y = linear_sum_assignment(cost_matrix)
        return np.array(list(zip(x, y)))

def iou_batch(bb_test, bb_gt):
    """
    From SORT: Computes IOU between two bboxes in the form [x1,y1,x2,y2]
    """
    bb_gt = np.expand_dims(bb_gt, 0)
    bb_test = np.expand_dims(bb_test, 1)
    
    xx1 = np.maximum(bb_test[..., 0], bb_gt[..., 0])
    yy1 = np.maximum(bb_test[..., 1], bb_gt[..., 1])
    xx2 = np.minimum(bb_test[..., 2], bb_gt[..., 2])
    yy2 = np.minimum(bb_test[..., 3], bb_gt[..., 3])
    w = np.maximum(0., xx2 - xx1)
    h = np.maximum(0., yy2 - yy1)
    wh = w * h
    o = wh / ((bb_test[..., 2] - bb_test[..., 0]) * (bb_test[..., 3] - bb_test[..., 1])                                      
        + (bb_gt[..., 2] - bb_gt[..., 0]) * (bb_gt[..., 3] - bb_gt[..., 1]) - wh)                                              
    return(o)  

class KalmanBoxTracker(object):
    count = 0
    def __init__(self, bbox):
        # [u,v,s,r] -> center_x, center_y, scale, ratio
        self.kf = KalmanFilter(dim_x=7, dim_z=4) 
        self.kf.F = np.array([[1,0,0,0,1,0,0],[0,1,0,0,0,1,0],[0,0,1,0,0,0,1],[0,0,0,1,0,0,0],  [0,0,0,0,1,0,0],[0,0,0,0,0,1,0],[0,0,0,0,0,0,1]])
        self.kf.H = np.array([[1,0,0,0,0,0,0],[0,1,0,0,0,0,0],[0,0,1,0,0,0,0],[0,0,0,1,0,0,0]])

        self.kf.R[2:,2:] *= 10.
        self.kf.P[4:,4:] *= 1000. 
        self.kf.P *= 10.
        self.kf.Q[-1,-1] *= 0.01
        self.kf.Q[4:,4:] *= 0.01
        
        self.kf.x[:4] = self.convert_bbox_to_z(bbox)
        self.time_since_update = 0
        self.id = KalmanBoxTracker.count
        KalmanBoxTracker.count += 1
        self.history = []
        self.hits = 0
        self.hit_streak = 0
        self.age = 0
        
        # Stored physics state
        self.centroid_history_birdseye = []
        self.velocity_mps = 0.0

    def update(self, bbox):
        self.time_since_update = 0
        self.history = []
        self.hits += 1
        self.hit_streak += 1
        self.kf.update(self.convert_bbox_to_z(bbox))

    def predict(self):
        if((self.kf.x[6]+self.kf.x[2])<=0):
            self.kf.x[6] *= 0.0
        self.kf.predict()
        self.age += 1
        if(self.time_since_update>0):
            self.hit_streak = 0
        self.time_since_update += 1
        self.history.append(self.convert_x_to_bbox(self.kf.x))
        return self.history[-1]
        
    def get_state(self):
        return self.convert_x_to_bbox(self.kf.x)

    @staticmethod
    def convert_bbox_to_z(bbox):
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        x = bbox[0] + w/2.
        y = bbox[1] + h/2.
        s = w * h   
        r = w / float(h)
        return np.array([x, y, s, r]).reshape((4, 1))

    @staticmethod
    def convert_x_to_bbox(x,score=None):
        w = np.sqrt(x[2] * x[3])
        h = x[2] / w
        if(score==None):
          return np.array([x[0]-w/2.,x[1]-h/2.,x[0]+w/2.,x[1]+h/2.]).reshape((1,4))
        else:
          return np.array([x[0]-w/2.,x[1]-h/2.,x[0]+w/2.,x[1]+h/2.,score]).reshape((1,5))

class Sort(object):
    def __init__(self, max_age=1, min_hits=3, iou_threshold=0.3):
        self.max_age = max_age
        self.min_hits = min_hits
        self.iou_threshold = iou_threshold
        self.trackers = []
        self.frame_count = 0

    def update(self, dets=np.empty((0, 5))):
        self.frame_count += 1
        
        # get predicted locations from existing trackers.
        trks = np.zeros((len(self.trackers), 5))
        to_del = []
        ret = []
        for t, trk in enumerate(trks):
            pos = self.trackers[t].predict()[0]
            trk[:] = [pos[0], pos[1], pos[2], pos[3], 0]
            if np.any(np.isnan(pos)):
                to_del.append(t)
        trks = np.ma.compress_rows(np.ma.masked_invalid(trks))
        for t in reversed(to_del):
            self.trackers.pop(t)
            
        matched, unmatched_dets, unmatched_trks = self.associate_detections_to_trackers(dets, trks, self.iou_threshold)

        # update matched trackers with assigned detections
        for m in matched:
            self.trackers[m[1]].update(dets[m[0], :])

        # create and initialise new trackers for unmatched detections
        for i in unmatched_dets:
            trk = KalmanBoxTracker(dets[i,:])
            self.trackers.append(trk)
            
        i = len(self.trackers)
        for trk in reversed(self.trackers):
            d = trk.get_state()[0]
            if (trk.time_since_update < 1) and (trk.hit_streak >= self.min_hits or self.frame_count <= self.min_hits):
                ret.append(np.concatenate((d, [trk.id+1])).reshape(1, -1)) # +1 as MOT benchmark requires positive
            i -= 1
            if(trk.time_since_update > self.max_age):
                self.trackers.pop(i)
                
        if(len(ret)>0):
            return np.concatenate(ret)
        return np.empty((0,5))
        
    @staticmethod
    def associate_detections_to_trackers(dets, trks, iou_threshold=0.3):
        if(len(trks) == 0):
            return np.empty((0,2),dtype=int), np.arange(len(dets)), np.empty((0,5),dtype=int)
            
        iou_matrix = iou_batch(dets, trks)

        if min(iou_matrix.shape) > 0:
            a = (iou_matrix > iou_threshold).astype(np.int32)
            if a.sum(1).max() == 1 and a.sum(0).max() == 1:
                matched_indices = np.stack(np.where(a), axis=1)
            else:
                matched_indices = linear_assignment(-iou_matrix)
        else:
            matched_indices = np.empty(shape=(0,2))

        unmatched_dets = []
        for d, det in enumerate(dets):
            if(d not in matched_indices[:,0]):
                unmatched_dets.append(d)
                
        unmatched_trks = []
        for t, trk in enumerate(trks):
            if(t not in matched_indices[:,1]):
                unmatched_trks.append(t)

        matches = []
        for m in matched_indices:
            if(iou_matrix[m[0], m[1]] < iou_threshold):
                unmatched_dets.append(m[0])
                unmatched_trks.append(m[1])
            else:
                matches.append(m.reshape(1,2))
                
        if(len(matches)==0):
            matches = np.empty((0,2),dtype=int)
        else:
            matches = np.concatenate(matches,axis=0)

        return matches, np.array(unmatched_dets), np.array(unmatched_trks)


# ----- INVERSE PERSPECTIVE MAPPING (IPM) & GAP CALCULATION -----

# Default standard homography matrix (Will be overridden by specific camera calibrations)
# Projects TxDOT CCTV frames into Bird's-Eye Top-Down physical space.
DEFAULT_H_MATRIX = np.array([
    [ 2.5,  0.0, -500],
    [ 0.0,  5.0, -1000],
    [ 0.0,  0.002, 1.0]
])

def pixel_to_birdseye(x, y, H=DEFAULT_H_MATRIX):
    """ Converts a pixel coordinate (x, y) into a physical Bird's-Eye View relative coordinate. """
    p_img = np.array([x, y, 1.0])
    p_bird = H.dot(p_img)
    x_b = p_bird[0] / p_bird[2]
    y_b = p_bird[1] / p_bird[2]
    return np.array([x_b, y_b])

def calculate_physical_gap(bboxA, bboxB, H=DEFAULT_H_MATRIX):
    """
    Calculates physical distance in meters between two bounding boxes.
    Assumes bounding boxes are [x1, y1, x2, y2]. Uses bottom-center centroid.
    """
    cA_x = (bboxA[0] + bboxA[2]) / 2.0
    cA_y = bboxA[3] # Bottom of bounding box (where car touches road)
    
    cB_x = (bboxB[0] + bboxB[2]) / 2.0
    cB_y = bboxB[3]

    bA = pixel_to_birdseye(cA_x, cA_y, H)
    bB = pixel_to_birdseye(cB_x, cB_y, H)
    
    # Euclidean distance in IPM projected space
    dist = np.linalg.norm(bA - bB)
    return dist
