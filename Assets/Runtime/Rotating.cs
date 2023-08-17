using UnityEngine;

public class Rotating : MonoBehaviour
{ 
    [Range(0f, 100f)] 
    public float speed = 10.0f;

    // Update is called once per frame
    void Update()
    {
        float angle = Time.deltaTime * speed;
        transform.Rotate(0, angle, 0, Space.World);
    }
}
