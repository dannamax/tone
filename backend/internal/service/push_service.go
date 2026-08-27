package service

import (
	"context"
	"errors"
	"log"

	"seeker/internal/repository"
	"seeker/pkg/apns"
)

// PushService APNs 远程推送：业务事件产生通知时同步触达离线用户
// （App 退后台后 WebSocket 断开，推送是唯一实时通道）。
// APNs 未配置（无 .p8 key）时为 no-op，不影响任何主流程。
type PushService struct {
	deviceRepo *repository.DeviceTokenRepo
	client     *apns.Client
}

func NewPushService(deviceRepo *repository.DeviceTokenRepo) *PushService {
	return &PushService{
		deviceRepo: deviceRepo,
		client:     apns.NewClient(),
	}
}

// SendToUser 向用户全部已登记设备异步推送（不阻塞业务主流程，失败仅记日志）。
// data 里的自定义键会放进推送 payload 顶层，客户端可据此路由到具体任务页。
func (s *PushService) SendToUser(ctx context.Context, userID, title, body string, data map[string]string) {
	go func() {
		tokens, err := s.deviceRepo.FindByUser(context.Background(), userID)
		if err != nil {
			log.Printf("[Push] list tokens for %s: %v", userID, err)
			return
		}
		for _, tk := range tokens {
			sent, err := s.client.Send(tk, title, body, data)
			if err != nil {
				if errors.Is(err, apns.ErrUnregistered) {
					_ = s.deviceRepo.Delete(context.Background(), tk) // 设备已卸载
				} else if len(tk) > 12 {
					log.Printf("[Push] send to %s...: %v", tk[:12], err)
				}
			} else if sent && len(tk) > 12 {
				log.Printf("[Push] sent to %s... (%s)", tk[:12], title)
			}
		}
	}()
}

// notifyAndPush 落库通知 + 触达离线设备推送（App 退后台后 WS 断开，推送是唯一实时通道）。
// push 为 nil 或 APNs 未配置时自动退化为仅落库。
func notifyAndPush(
	ctx context.Context,
	n *repository.NotificationRepo,
	p *PushService,
	userID, notifyType, title, body, taskID string,
) {
	n.Create(ctx, userID, notifyType, title, body, taskID)
	if p != nil {
		p.SendToUser(ctx, userID, title, body, map[string]string{
			"task_id": taskID,
			"type":    notifyType,
		})
	}
}
